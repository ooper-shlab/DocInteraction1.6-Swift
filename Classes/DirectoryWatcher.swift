//
//  DirectoryWatcher.swift
//  DocInteraction
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/17.
//
//
/*
     File: DirectoryWatcher.h
     File: DirectoryWatcher.m
 Abstract:
 Object used to monitor the contents of a given directory by using
 "kqueue": a kernel event notification mechanism.

  Version: 1.6

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.

 */

import Foundation

@objc(DirectoryWatcherDelegate)
protocol DirectoryWatcherDelegate: NSObjectProtocol {
    func directoryDidChange(folderWatcher: DirectoryWatcher)
}

@objc(DirectoryWatcher)
class DirectoryWatcher: NSObject {
    weak var delegate: DirectoryWatcherDelegate?
    
    private var dirFD: CInt = 0
    
    private var dirKQRef: dispatch_source_t?
    
    
    //MARK: -
    
    override init() {
        super.init()
        delegate = nil
        
        dirFD = -1
        
        dirKQRef = nil
        
    }
    
    deinit {
        self.invalidate()
    }
    
    class func watchFolderWithPath(watchPath: String, delegate watchDelegate: DirectoryWatcherDelegate) -> DirectoryWatcher? {
        var retVal: DirectoryWatcher? = nil
        let tempManager = DirectoryWatcher()
        tempManager.delegate = watchDelegate
        if tempManager.startMonitoringDirectory(watchPath) {
            // Everything appears to be in order, so return the DirectoryWatcher.
            // Otherwise we'll fall through and return NULL.
            retVal = tempManager
        }
        return retVal
    }
    
    func invalidate() {
        if dirKQRef != nil {
            dispatch_source_cancel(dirKQRef!)
            dirKQRef = nil
            // We don't need to close the kq, CFFileDescriptorInvalidate closed it instead.
            // Change the value so no one thinks it's still live.
        }
        
        if dirFD != -1 {
            close(dirFD)
            dirFD = -1
        }
    }
    
    
    //MARK: -
    
    private func kqueueFired() {
        
        // call our delegate of the directory change
        delegate?.directoryDidChange(self)
        
    }
    
    //static void KQCallback(CFFileDescriptorRef kqRef, CFOptionFlags callBackTypes, void *info)
    //{
    //    DirectoryWatcher *obj;
    //
    //    obj = (__bridge DirectoryWatcher *)info;
    //    assert([obj isKindOfClass:[DirectoryWatcher class]]);
    //    assert(kqRef == obj->dirKQRef);
    //    assert(callBackTypes == kCFFileDescriptorReadCallBack);
    //
    //    [obj kqueueFired];
    //}
    
    private func startMonitoringDirectory(dirPath: String) -> Bool {
        // Double initializing is not going to work...
        if dirKQRef == nil && dirFD == -1 {
            // Open the directory we're going to watch
            dirFD = open((dirPath as NSString).fileSystemRepresentation, O_EVTONLY)
            if dirFD >= 0 {
                // Create a kqueue for our event messages...
                
                let dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                    UInt(dirFD),
                    DISPATCH_VNODE_WRITE,
                    dispatch_get_main_queue())
                if dispatchSource != nil {
                    dispatch_source_set_event_handler(dispatchSource, {[weak self] in
                        self?.kqueueFired()
                        return
                    })
                    dispatch_resume(dispatchSource)
                    dirKQRef = dispatchSource
                    // If everything worked, return early and bypass shutting things down
                    return true
                    // Couldn't create a runloop source, invalidate and release the CFFileDescriptorRef
                }
                // file handle is open, but something failed, close the handle...
                close(dirFD)
                dirFD = -1
            }
        }
        return false
    }
}