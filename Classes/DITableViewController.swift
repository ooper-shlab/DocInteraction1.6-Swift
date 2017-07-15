//
//  DITableViewController.swift
//  DocInteraction
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/17.
//
//
/*
     File: DITableViewController.h
     File: DITableViewController.m
 Abstract: The table view that display docs of different types.
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

import UIKit
import QuickLook

let documents: [String] = [
    "Text Document.txt",
    "Image Document.jpg",
    "PDF Document.pdf",
    "HTML Document.html"
]

let kRowHeight: CGFloat = 58.0

//MARK: -

@objc(DITableViewController)
class DITableViewController: UITableViewController, QLPreviewControllerDataSource,
    QLPreviewControllerDelegate,
    DirectoryWatcherDelegate,
UIDocumentInteractionControllerDelegate {
    
    private var docWatcher: DirectoryWatcher!
    private var documentURLs: [URL] = []
    private var docInteractionController: UIDocumentInteractionController!
    
    //MARK: -
    
    private func setupDocumentController(with url: URL) {
        //checks if docInteractionController has been initialized with the URL
        if self.docInteractionController == nil {
            self.docInteractionController = UIDocumentInteractionController(url: url)
            self.docInteractionController.delegate = self
        } else {
            self.docInteractionController.url = url
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // start monitoring the document directory…
        self.docWatcher = DirectoryWatcher.watchFolder(at: self.applicationDocumentsDirectoryURL, delegate: self)

        // scan for existing documents
        self.directoryDidChange(self.docWatcher)
    }
    
    // if we installed a custom UIGestureRecognizer (i.e. long-hold), then this would be called
    
    @objc func handleLongPress(_ longPressGesture: UILongPressGestureRecognizer) {
        if longPressGesture.state == .began {
            let cellIndexPath = self.tableView.indexPathForRow(at: longPressGesture.location(in: self.tableView))!
            
            var fileURL: URL
            if cellIndexPath.section == 0 {
                // for section 0, we preview the docs built into our app
                fileURL = Bundle.main.url(forResource: documents[cellIndexPath.row], withExtension: nil)!
            } else {
                // for secton 1, we preview the docs found in the Documents folder
                fileURL = self.documentURLs[cellIndexPath.row]
            }
            self.docInteractionController.url = fileURL
            
            self.docInteractionController.presentOptionsMenu(from: longPressGesture.view!.frame, in: longPressGesture.view!, animated: true)
        }
    }
    
    
    //MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Initializing each section with a set of rows
        if section  == 0 {
            return documents.count
        } else {
            return self.documentURLs.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String? = nil
        // setting headers for each section
        if section == 0 {
            title = "Example Documents"
        } else {
            if self.documentURLs.count > 0 {
                title = "Documents folder"
            }
        }
        
        return title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "cellID"
        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
            cell!.accessoryType = .disclosureIndicator
        }
        
        var fileURL: URL
        
        if indexPath.section == 0 {
            // first section is our build-in documents
            fileURL = Bundle.main.url(forResource: documents[indexPath.row], withExtension: nil)!
        } else {
            // second section is the contents of the Documents folder
            fileURL = self.documentURLs[indexPath.row]
        }
        self.setupDocumentController(with: fileURL)
        
        // layout the cell
        cell!.textLabel?.text = fileURL.lastPathComponent
        let iconCount = self.docInteractionController.icons.count
        if iconCount > 0 {
            cell!.imageView?.image = self.docInteractionController.icons.last
        }
        
        let fileURLString = self.docInteractionController.url!.path
        let fileAttributes = try! FileManager.default.attributesOfItem(atPath: fileURLString)
        let fileSize = fileAttributes[.size] as! Int64
        let fileSizeStr = ByteCountFormatter.string(fromByteCount: fileSize,
                                                    countStyle: .file)
        let uti = self.docInteractionController.uti ?? ""
        cell!.detailTextLabel?.text = "\(fileSizeStr) - \(uti)"
        
        // attach to our view any gesture recognizers that the UIDocumentInteractionController provides
        //cell.imageView.userInteractionEnabled = YES;
        //cell.contentView.gestureRecognizers = self.docInteractionController.gestureRecognizers;
        //
        // or
        // add a custom gesture recognizer in lieu of using the canned ones
        //
        let longPressGesture =
            UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        cell!.imageView?.addGestureRecognizer(longPressGesture)
        cell!.imageView?.isUserInteractionEnabled = true
        
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return kRowHeight
    }
    
    
    //MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // three ways to present a preview:
        // 1. Don't implement this method and simply attach the canned gestureRecognizers to the cell
        //
        // 2. Don't use canned gesture recognizers and simply use UIDocumentInteractionController's
        //      presentPreviewAnimated: to get a preview for the document associated with this cell
        //
        // 3. Use the QLPreviewController to give the user preview access to the document associated
        //      with this cell and all the other documents as well.
        
        // for case 2 use this, allowing UIDocumentInteractionController to handle the preview:
        /*
         NSURL *fileURL;
         if (indexPath.section == 0)
         {
         fileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:documents[indexPath.row] ofType:nil]];
         }
         else
         {
         fileURL = [self.documentURLs objectAtIndex:indexPath.row];
         }
         [self setupDocumentControllerWithURL:fileURL];
         [self.docInteractionController presentPreviewAnimated:YES];
         */
        
        // for case 3 we use the QuickLook APIs directly to preview the document -
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        
        // start previewing the document at the current section index
        previewController.currentPreviewItemIndex = indexPath.row
        self.navigationController?.pushViewController(previewController, animated: true)
    }
    
    
    //MARK: - UIDocumentInteractionControllerDelegate
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    
    //MARK: - QLPreviewControllerDataSource
    
    // Returns the number of items that the preview controller should preview
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        var numToPreview = 0
        
        let selectedIndexPath = self.tableView.indexPathForSelectedRow
        if (selectedIndexPath?.section ?? 0) == 0 {
            numToPreview = documents.count
        } else {
            numToPreview = self.documentURLs.count
        }
        
        return numToPreview
    }
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        // if the preview dismissed (done button touched), use this method to post-process previews
    }
    
    // returns the item that the preview controller should preview
    func previewController(_ controller: QLPreviewController, previewItemAt idx: Int) -> QLPreviewItem {
        var fileURL: URL
        
        let selectedIndexPath = self.tableView.indexPathForSelectedRow
        if (selectedIndexPath?.section ?? 0) == 0 {
            fileURL = Bundle.main.url(forResource: documents[idx], withExtension: nil)!
        } else {
            fileURL = self.documentURLs[idx]
        }
        
        return fileURL as QLPreviewItem
    }
    
    
    //MARK: - File system support
    
    private var applicationDocumentsDirectoryURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    }

    func directoryDidChange(_ folderWatcher: DirectoryWatcher) {
        self.documentURLs.removeAll(keepingCapacity: true)
        
        let documentsDirectoryURL = self.applicationDocumentsDirectoryURL

        let documentsDirectoryContentURLs = try? FileManager.default.contentsOfDirectory(at: documentsDirectoryURL, includingPropertiesForKeys: nil)

        for fileURL in documentsDirectoryContentURLs ?? [] {
            let filePath = fileURL.path
            let curFileName = fileURL.lastPathComponent
        
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory)
            
            // proceed to add the document URL to our list (ignore the "Inbox" folder)
            if !isDirectory.boolValue && curFileName == "Inbox" {
                self.documentURLs.append(fileURL)
            }
        }
        
        self.tableView.reloadData()
    }
    
}
