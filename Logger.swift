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

public struct LogParameters {
    let function: String
    let file: String
    let line: Int
    
    let className: String?
    let timeStamp: NSDate
    
    public init(function: String, file: String, line: Int, className: String? = nil, timeStamp: NSDate = NSDate()) {
        self.function = function
        self.file = file
        self.line = line
        self.className = className
        self.timeStamp = timeStamp
    }
    
    /** Copies the struct but overwrites the className */
    public func withClassName(className: String) -> LogParameters {
        return LogParameters(function: self.function, file: self.file, line: self.line, className: className, timeStamp: self.timeStamp)
    }
}

public protocol Logger {
    var level: LogLevel { get set }
    func write(level level:LogLevel, @autoclosure message:(Void -> String), parameters: LogParameters)
}

public extension Logger {
    public func error(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        write(level: .Error, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    public func warn(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        write(level: .Warn, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    public func info(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        write(level: .Info, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    public func debug(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        write(level: .Debug, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    public func verbose(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        write(level: .Verbose, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    
    // note className needs to be a parameter on these things because swift 2.2 has static dispatch
    // of protocol extension methods, so ClassLogger can't override them
}

public typealias LogFormatter = (String, LogParameters) -> String

private var iso8601dateFormatter: NSDateFormatter?

public func iso8601String(date:NSDate) -> String {
    var formatter: NSDateFormatter
    if let f = iso8601dateFormatter {
        formatter = f
    } else {
        formatter = NSDateFormatter()
        let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.locale = enUSPosixLocale
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    }
    return formatter.stringFromDate(date)
}

public func defaultLogFormatter(message: String, parameters: LogParameters) -> String {
    let timeStr = iso8601String(parameters.timeStamp)
    if let className = parameters.className {
        return "\(timeStr) [\(className)] \(message)"
    } else {
        return "\(timeStr) \(message)"
    }
}

public struct LogConfiguration {
    /** The full path to the log output file. 
     If rotation is enabled, rotated logs will take this name but insert a number in between
     the name and the file extension. If no file extension is specified, .log will be used */
    public let fileUrl:NSURL
    
    /** If set, log file writes and rotation operations are performed on a background queue.
     Else, writes are performed synchronously inline with the caller, and dispatch_sync is used.
     Defaults to true */
    public let async:Bool
    
    /** Formatter function which produces the output string */
    public let formatter:LogFormatter
    
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
        fileUrl: NSURL, // this one is mandatory
        formatter: LogFormatter = defaultLogFormatter,
        async: Bool = true,
        rotationFileSize: Int? = nil,
        rotationInterval: NSTimeInterval? = nil,
        rotationKeepCount: Int? = nil,
        fileEncoding: NSStringEncoding = NSUTF8StringEncoding,
        alwaysFlush: Bool = true)
    {
        self.fileUrl = fileUrl
        self.formatter = formatter
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
    public static var singletonInstance: Log = Log()
    
    // Static interface which forwards to singletonInstance, makes it nice if you don't need multiple loggers
    
    public static func error(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        singletonInstance.write(level: .Error, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    public static func warn(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        singletonInstance.write(level: .Warn, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    public static func info(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        singletonInstance.write(level: .Info, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    public static func debug(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        singletonInstance.write(level: .Debug, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    public static func verbose(@autoclosure message:(Void -> String), function:String = #function, file:String = #file, line:Int = #line, className: String? = nil) {
        singletonInstance.write(level: .Verbose, message: message, parameters: LogParameters(function: function, file: file, line: line, className: className))
    }
    
    public static func createForClass(klass: Any.Type) -> Logger {
        return singletonInstance.createForClass(klass)
    }
    
    public static var configuration: LogConfiguration {
        get { return singletonInstance.configuration }
        set { singletonInstance.configuration = newValue }
    }
    
    // Private properties
    
    private var _configuration: LogConfiguration?
    private var _writer: LogFileWriter?
    
    // Logger protocol
    
    public func write(level level: LogLevel, @autoclosure message: (Void -> String), parameters:LogParameters) {
        
        // if we haven't got a writer assigned, or if the level isn't enough, do nothing
        guard let writer = _writer where level <= self.level else {
            return
        }
        
        // we're definitely going to do the writing. Resolve the string and write to the log file
        writer.write(message())
    }
    
    public var level = LogLevel.Debug {
        didSet {
            
        }
    }
    
    // Public Instance methods
    
    public func createForClass(klass: Any.Type) -> Logger {
        return ClassLogger(parent: Log.singletonInstance, level: level, class: klass)
    }
    
    public var configuration: LogConfiguration {
        get {
            guard let c = _configuration else {
                fatalError("get configuration as none is assigned")
            }
            return c
        }
        set {
            _configuration = newValue
            // now that we have some configuration, create the logWriter
            _writer = LogFileWriter(configuration: newValue)
        }
    }
}

public class ClassLogger : Logger {
    private let _parent: Logger
    private let _class: Any.Type
    
    public var level:LogLevel // can change if reconfigured during runtime
    
    private init(parent: Logger, level: LogLevel, class klass: Any.Type) {
        self._parent = parent
        self._class = klass
        self.level = level
    }
    
    // Logger protocol
    
    public func write(level level: LogLevel, @autoclosure message: (Void -> String), parameters: LogParameters) {
        if level > self.level {
            return
        }
        
        _parent.write(level: level, message: message(), parameters: parameters.withClassName(String(_class)))
    }
}

public func <(a:LogLevel, b:LogLevel) -> Bool {
    return a.rawValue < b.rawValue
}
