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

import SwiftSyntax

/// Generates grammar doc comments for syntax nodes.
struct GrammarGenerator {

  /// Returns grammar for a ``TokenChoice``.
  ///
  /// - parameters:
  ///   - tokenChoice: ``TokenChoice`` to describe
  ///   - backticks: Whether to wrap the token choice in backticks
  private func grammar(for tokenChoice: TokenChoice) -> String {
    switch tokenChoice {
    case .keyword(let keyword):
      return "`'\(keyword.spec.name)'`"
    case .token(let token):
      let tokenSpec = token.spec
      if let tokenText = tokenSpec.text {
        return "`'\(tokenText)'`"
      } else {
        return "`<\(tokenSpec.varOrCaseName)>`"
      }
    }
  }

  private func grammar(for child: Child) -> String {
    let optionality = child.isOptional ? "?" : ""
    switch child.kind {
    case .node(let kind):
      return "``\(kind.syntaxType)``\(optionality)"
    case .nodeChoices(let choices):
      let choicesDescriptions = choices.map { grammar(for: $0) }
      return "(\(choicesDescriptions.joined(separator: " | ")))\(optionality)"
    case .collection(kind: let kind, _, _, _):
      return "``\(kind.syntaxType)``\(optionality)"
    case .token(let choices, _, _):
      if choices.count == 1 {
        return "\(grammar(for: choices.first!))\(optionality)"
      } else {
        let choicesDescriptions = choices.map { grammar(for: $0) }
        return "(\(choicesDescriptions.joined(separator: " | ")))\(optionality)"
      }
    }
  }

  /// Generates a markdown list containing the children’s names and their
  /// grammar.
  ///
  /// - Parameter children: The children to show in the list
  static func childrenList(for children: [Child]) -> String {
    let generator = GrammarGenerator()
    return
      children
      .filter { !$0.isUnexpectedNodes }
      .map { " - `\($0.varOrCaseName)`: \(generator.grammar(for: $0))" }
      .joined(separator: "\n")
  }

  /// Generates the list of possible token kinds for this particular ``Child``.
  /// The child must be of kind ``ChildKind/token``. Otherwise, an empty string will be returned.
  static func childTokenChoices(for child: Child) -> String {
    let generator = GrammarGenerator()

    if case .token(let choices, _, _) = child.kind {
      if choices.count == 1 {
        return " \(generator.grammar(for: choices.first!))"
      } else {
        return choices.map { " - \(generator.grammar(for: $0))" }.joined(separator: "\n")
      }
    } else {
      return ""
    }
  }
}
