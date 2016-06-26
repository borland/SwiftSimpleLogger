//
//  LogFileWriter.swift
//  SwiftSimpleLogger
//
//  Created by Orion Edwards on 27/06/16.
//  Copyright © 2016 Orion Edwards. All rights reserved.
//

import Foundation

public class LogFileWriter {
    private let _configuration: LogConfiguration
    private let _nl: NSData
    private let _queue = dispatch_queue_create("LogFileWriter", nil)
    
    public init(configuration: LogConfiguration) {
        _configuration = configuration
        _nl = "\n".dataUsingEncoding(_configuration.fileEncoding)!
    }
    
    public func write(message: String) {
        if _configuration.async {
            dispatch_async(_queue) {
                self.internalWrite(message)
            }
        } else {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            internalWrite(message)
        }
    }
    
    private func internalWrite(message: String) {
        guard !_configuration.filePath.isEmpty else {
            print("LogFileWriter: filePath is empty, can't write!")
            return // Can't write to log without having configured a valid path
        }
        
        guard let file = NSFileHandle(forUpdatingAtPath: _configuration.filePath) else {
            print("LogFileWriter: can't open file at \(_configuration.filePath)")
            return // can't create the file
        }
        var fileOpen = true
        defer {
            if fileOpen {
                file.closeFile()
            }
        }
        
        guard let data = message.dataUsingEncoding(_configuration.fileEncoding) else {
            print("LogFileWriter: can't convert string to specified encoding")
            return // can't create the file
        }
        
        file.writeData(data)
        file.writeData(_nl)
        
        if _configuration.alwaysFlush {
            file.synchronizeFile() // do we want to do this every time?
        }
        
        fileOpen = false
        file.closeFile()
        
        if _configuration.rotationFileSize != nil || _configuration.rotationInterval != nil {
            var stats = stat()
            if fstat(file.fileDescriptor, &stats) != 0 { // failed
                print("LogFileWriter: can't stat file, rotation, etc won't work")
                return
            }
            
            if let maxSize = _configuration.rotationFileSize where stats.st_size >= off_t(maxSize) {
                // rotate, file too big
                rotate()
                return
            }
            
            if let maxAge = _configuration.rotationInterval {
                let d = Double(stats.st_birthtimespec.tv_sec) +
                    (Double(stats.st_birthtimespec.tv_nsec) / Double(NSEC_PER_SEC))
                
                let ageLimit = NSDate().timeIntervalSince1970 - maxAge
                if d < ageLimit {
                    // rotate, file too old
                    rotate()
                    return
                }
            }
        }
    }
    
    private func rotate() {
        let originalUrl = NSURL(fileURLWithPath: _configuration.filePath)
        let ext = originalUrl.pathExtension ?? "log"
        
        // crash if someone gives us an invalid file name
        let pathNoExt = originalUrl.URLByDeletingPathExtension!
        
        let keepCount = _configuration.rotationKeepCount ?? 10000
        
        let deriveUrl:(Int) -> NSURL = { (num) in
            
        }
        
        let ops:[AnyObject] = []
        for i in 0..<keepCount {
            let srcUrl = deriveUrl(i)
            
            let targetUrl = deriveUrl(i + 1)
            
//            ops.append { moveFile(originalUrl, ".1") }
        }
        //ops: move baseName to baseName.1
    }
}