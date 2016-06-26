//
//  Logger.swift
//  SwiftSimpleLogger
//
//  Created by Orion Edwards on 24/06/16.
//  Copyright © 2016 Orion Edwards. All rights reserved.
//

import Foundation

public enum LogLevel : Int, Comparable {
    case Error, Warn, Info, Debug, Verbose
}

public func <(a:LogLevel, b:LogLevel) -> Bool {
    return a.rawValue < b.rawValue
}

public protocol Logger {
    var level: LogLevel { get set }
    func write(level level:LogLevel, @autoclosure message:(Void -> String), function:String, file:String, line:Int)
}

public extension Logger {
    public func error(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        write(level: .Error, message: message, function: function, file: file, line: line)
    }
    public func warn(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        write(level: .Warn, message: message, function: function, file: file, line: line)
    }
    public func info(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        write(level: .Info, message: message, function: function, file: file, line: line)
    }
    public func debug(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        write(level: .Debug, message: message, function: function, file: file, line: line)
    }
    public func verbose(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        write(level: .Verbose, message: message, function: function, file: file, line: line)
    }
}

public protocol LogFactoryType {
    var level: LogLevel { get set }
    func create(class klass: Any.Type) -> Logger
}

public class LogFactory : LogFactoryType {
    public static var singletonInstance: LogFactoryType = LogFactory() // reassignable
    
    /** Use this method to create class loggers */
    public static func create(class klass: Any.Type) -> Logger {
        return singletonInstance.create(class: klass)
    }
    
    // instance methods
    
    public var level: LogLevel = .Debug // can change if reconfigured during runtime
    
    public func create(class klass: Any.Type) -> Logger {
        Logger.self
        return ClassLogger(parent: Log.singletonInstance, level: level, class: klass)
    }
}

public struct LogConfiguration {
    /** The full path to the log output file. 
     If rotation is enabled, rotated logs will take this name but insert a number in between
     the name and the file extension. If no file extension is specified, .log will be used */
    public let filePath:String
    
    /** If set, log file writes and rotation operations are performed on a background queue.
     Else, writes are performed synchronously inline with the caller, and dispatch_sync is used.
     Defaults to true */
    public let async:Bool
    
    /** If set, file writes will always be flushed using NSFileHandle -synchronizeFile. Else, they won't.
     Defaults to true */
    public let alwaysFlush:Bool
    
    /** If set, the log will rotate when it reaches this size.
     If not set, logs won't be rotated based on size. */
    public let rotationFileSize:Int?
    
    /** If set, the log will rotate if it survives this long (without being rotated due to file size).
     Else, logs won't be rotated based on time */
    public let rotationInterval:NSTimeInterval?
    
    /** If set, after rotation if there are more than this number of log files (including the base one),
     the oldest file will be deleted.
     Else, all logs will be kept (dangerous!) */
    public let rotationKeepCount:Int?
    
    /** The text encoding used. Defaults to utf8 */
    public let fileEncoding: NSStringEncoding
    
    public init(
        filePath: String = "",
        async: Bool = true,
        rotationFileSize: Int? = nil,
        rotationInterval: NSTimeInterval? = nil,
        rotationKeepCount: Int? = nil,
        fileEncoding: NSStringEncoding = NSUTF8StringEncoding,
        alwaysFlush: Bool = true)
    {
        self.filePath = filePath
        self.async = async
        self.rotationFileSize = rotationFileSize
        self.rotationInterval = rotationInterval
        self.rotationKeepCount = rotationKeepCount
        self.fileEncoding = fileEncoding
        self.alwaysFlush = alwaysFlush
    }
}

/** This is the "Default" logger that you can use if you don't want to create a class logger.
 It also contains the singleton instance of the Root Logger that LogFactory refers to */
public class Log : Logger {
    /** reassignable, but reassigning the root logger may break things */
    public static var singletonInstance: Logger = Log()
    
    public static func error(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        singletonInstance.write(level: .Error, message: message, function: function, file: file, line: line)
    }
    public static func warn(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        singletonInstance.write(level: .Warn, message: message, function: function, file: file, line: line)
    }
    public static func info(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        singletonInstance.write(level: .Info, message: message, function: function, file: file, line: line)
    }
    public static func debug(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        singletonInstance.write(level: .Debug, message: message, function: function, file: file, line: line)
    }
    public static func verbose(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line) {
        singletonInstance.write(level: .Verbose, message: message, function: function, file: file, line: line)
    }
    
    // Logger protocol
    
    public func write(level level: LogLevel, @autoclosure message: (Void -> String), function: String, file: String, line: Int) {
        guard let writer = self.writer where level >= self.level else {
            return
        }
        
        // we're definitely going to do the writing. Resolve the string and write to the log file
        writer.write(message())
        
    }
    
    // Instance methods
    
    public var writer: LogFileWriter?
    
    public var level = LogLevel.Debug {
        didSet {
            
        }
    }
    
    public var configuration = LogConfiguration() {
        didSet {
            writer = LogFileWriter(configuration: configuration)
        }
    }
}

public class ClassLogger : Logger {
    private let parent: Logger
    private let klass: Any.Type
    
    public var level:LogLevel // can change if reconfigured during runtime
    
    private init(parent: Logger, level: LogLevel, class klass: Any.Type) {
        self.parent = parent
        self.klass = klass
        self.level = level
    }
    
    // Logger protocol
    
    public func write(level level: LogLevel, @autoclosure message: (Void -> String), function: String, file: String, line: Int) {
        if level < self.level {
            return
        }
        
        parent.write(level: level, message: "[\(klass)] \(message())", function: function, file: file, line: line)
    }
}