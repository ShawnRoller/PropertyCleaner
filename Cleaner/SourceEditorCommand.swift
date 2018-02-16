//
//  SourceEditorCommand.swift
//  Cleaner
//
//  Created by Shawn Roller on 1/19/18.
//  Copyright © 2018 Shawn Roller. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        removeUnusedProperties(invocation: invocation) { (done) in
            completionHandler(nil)
        }
    }
    
    private func removeUnusedProperties(invocation: XCSourceEditorCommandInvocation, completion: @escaping (Bool) -> Void) {
        for (lineIndex, line) in invocation.buffer.lines.enumerated() {
            guard let theLine = line as? String else { continue }
            guard theLine.count > 0 else { continue }
            do {
                let pattern = "((let)|(var))\\s[A-z]{1,100}"
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSMakeRange(0, theLine.count)
                let matches = regex.matches(in: theLine, options: [], range: range)
                for match in matches {
                    
                    let range: Range = Range(uncheckedBounds: (lower: match.range.lowerBound, upper: match.range.upperBound))
                    let start = theLine.index(theLine.startIndex, offsetBy: range.lowerBound + 4)
                    let end = theLine.index(theLine.startIndex, offsetBy: range.upperBound)
                    let variable = theLine[start..<end]
                    let lines = getLinesForVariable(String(variable), in: invocation.buffer.lines, checkLineIndex: lineIndex)
                    
                    if lines.count == 1 {
                        // Remove the line
                        let range = Range(uncheckedBounds: (lower: lineIndex, upper: lineIndex + 1))
                        let indexSet = IndexSet(integersIn: range)
                        invocation.buffer.lines.removeObjects(at: indexSet)
                        removeUnusedProperties(invocation: invocation, completion: completion)
                        return
                    }
                }
            } catch {
                continue
            }
        }
        completion(true)
    }
    
    private func getLinesForVariable(_ variable: String, in lines: NSMutableArray, checkLineIndex: Int) -> [Int] {
        
        var redeclarationLines = [Int]()
        var linesToRemove = [Int]()
        
        for (lineIndex, line) in lines.enumerated() {
            guard lineIndex != checkLineIndex else { continue }
            guard let theLine = line as? String else { continue }
            do {
                let pattern = "((let)|(var))\\s\(variable){1,100}"
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSMakeRange(0, theLine.count)
                let matches = regex.matches(in: theLine, options: [], range: range)
                if matches.count > 0 {
                    redeclarationLines.append(lineIndex)
                }
            } catch {
                print(error as NSError)
                return linesToRemove
            }
        }
        
        // If the variable was declared again, we don't want to remove it
        guard redeclarationLines.count == 0 else { return linesToRemove }
        
        linesToRemove.append(checkLineIndex)
        
        for (lineIndex, line) in lines.enumerated() {
            guard lineIndex != checkLineIndex else { continue }
            guard let theLine = line as? String else { continue }
            do {
                let pattern = "(\\W|\\s)(\(variable))(\\W|\\s)"
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSMakeRange(0, theLine.count)
                let matches = regex.matches(in: theLine, options: [], range: range)
                if matches.count > 0 {
                    linesToRemove.append(lineIndex)
                }
            } catch {
                print(error as NSError)
                return linesToRemove
            }
        }
        
        return linesToRemove
    }
    
}
