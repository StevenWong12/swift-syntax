//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import _InstructionCounter
import ArgumentParser
import Foundation
import SwiftParser
import SwiftSyntax

struct PerformanceTest: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "performance-test",
    abstract:
      "Parse all .swift files in '--directory' and its subdirectories '--iteration' times and output the average time (in milliseconds) one iteration took."
  )

  @Flag(name: .long, help: "Parse files incrementally")
  var incrementalParse: Bool = false

  @Option(help: "The directory in which all .swift files should be parsed")
  var directory: String

  @Option(help: "How many times should the directory be parsed?")
  var iterations: Int

  func run() throws {
    let sourceDir = URL(fileURLWithPath: self.directory)

    let files = try FileManager.default
      .enumerator(at: sourceDir, includingPropertiesForKeys: nil)!
      .compactMap({ $0 as? URL })
      .filter { $0.pathExtension == "swift" }
      .map { try Data(contentsOf: $0) }

    var incrementalParseTransition: IncrementalParseTransition? = nil
    var incrementalParseAffectRangeCollector: IncrementalParseNodeAffectRangeCollector? = nil

    var totalTime: TimeInterval = .zero
    let startInstructions = getInstructionsExecuted()
    var previousTreeDict: [Data: (SourceFileSyntax, IncrementalParseNodeAffectRangeCollector?)] = [:]
    for iter in 0..<self.iterations {
      for file in files {
        if incrementalParse == true {
          incrementalParseAffectRangeCollector = previousTreeDict[file]?.1 ?? IncrementalParseNodeAffectRangeCollector()
          if iter != 0 {
            incrementalParseTransition = IncrementalParseTransition(
              previousTree: previousTreeDict[file]!.0,
              edits: ConcurrentEdits(fromSequential: []),
              reusedNodeDelegate: nil
            )
          }
        }
        file.withUnsafeBytes { buf in
          let start = Date()
          let tree = Parser.parse(
            source: buf.bindMemory(to: UInt8.self),
            parseNodeAffectRange: incrementalParseAffectRangeCollector,
            parseTransition: incrementalParseTransition
          )
          totalTime += Date().timeIntervalSince(start)
          previousTreeDict[file] = (tree, incrementalParseAffectRangeCollector)
        }
      }
    }
    let endInstructions = getInstructionsExecuted()

    print("Time:         \(totalTime / Double(self.iterations) * 1000)ms")
    if endInstructions != startInstructions {
      // endInstructions == startInstructions only happens if we are on non-macOS
      // platforms that don't support `getInstructionsExecuted`. Don't display anything.
      print("Instructions: \(Double(endInstructions - startInstructions) / Double(self.iterations))")
    }
  }
}
