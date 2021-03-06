//
//  SearchTextField.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/3/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Carbon.HIToolbox

import FSNotesCore_macOS

class SearchTextField: NSTextField, NSTextFieldDelegate {

    public var vcDelegate: ViewController!
    
    private var filterQueue = OperationQueue.init()
    private var searchTimer = Timer()
    
    public var searchQuery = ""
    public var selectedRange = NSRange()
    public var skipAutocomplete = false
        
    override func controlTextDidEndEditing(_ obj: Notification) {
        focusRingType = .none
    }
    
    override func keyUp(with event: NSEvent) {
        if (event.keyCode == kVK_DownArrow) {
            vcDelegate.focusTable()
            vcDelegate.notesTableView.selectNext()
            return
        }
        
        if (event.keyCode == kVK_LeftArrow && stringValue.count == 0) {
            vcDelegate.storageOutlineView.window?.makeFirstResponder(vcDelegate.storageOutlineView)
            vcDelegate.storageOutlineView.selectRowIndexes([1], byExtendingSelection: false)
            return
        }
        
        if event.keyCode == kVK_Return {
            vcDelegate.focusEditArea()
        }

        if self.skipAutocomplete {
           self.skipAutocomplete = false
        }
    }
 
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if (
            event.keyCode == kVK_Escape
            || (
                [kVK_ANSI_L, kVK_ANSI_N].contains(Int(event.keyCode))
                && event.modifierFlags.contains(.command)
            )
        ) {
            searchQuery = ""
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector.description {
        case "cancelOperation:":
            return true
        case "deleteBackward:":
            self.skipAutocomplete = true
            textView.deleteBackward(self)
            return true
        case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
            if let note = vcDelegate.editArea.getSelectedNote(), stringValue.count > 0, note.title.lowercased().starts(with: searchQuery.lowercased()) {
                vcDelegate.focusEditArea()
            } else {
                vcDelegate.makeNote(self)
            }
            return true
        case "insertTab:":
            vcDelegate.focusEditArea()
            vcDelegate.editArea.scrollToCursor()
            return true
        case "deleteWordBackward:":
            textView.deleteWordBackward(self)
            return true
        default:
            return false
        }
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        UserDataService.instance.searchTrigger = true
        
        filterQueue.cancelAllOperations()
        filterQueue.addOperation {
            DispatchQueue.main.async {
                self.vcDelegate.updateTable(search: true) {
                    if UserDefaultsManagement.focusInEditorOnNoteSelect {
                        self.searchTimer.invalidate()
                        self.searchTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1), target: self, selector: #selector(self.onEndSearch), userInfo: nil, repeats: false)
                    } else {
                        UserDataService.instance.searchTrigger = false
                    }
                }
            }
        }
    }
    
    @objc func onEndSearch() {
        UserDataService.instance.searchTrigger = false
    }
    
    public func suggestAutocomplete(_ note: Note) {
        if note.title == self.stringValue {
            return
        }
        
        let searchQuery = self.stringValue
        
        if note.title.lowercased().starts(with: searchQuery.lowercased()) {
            let text = searchQuery + note.title.suffix(note.title.count - searchQuery.count)
            stringValue = text
            currentEditor()?.selectedRange = NSRange(searchQuery.utf16.count..<note.title.utf16.count)
        }
    }
    
}
