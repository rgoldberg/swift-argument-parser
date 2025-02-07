//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if swift(>=5.11)
internal import ArgumentParserToolInfo
#elseif swift(>=5.10)
import ArgumentParserToolInfo
#else
@_implementationOnly import ArgumentParserToolInfo
#endif

struct BashCompletionsGenerator {
  /// Generates a Bash completion script for the given command.
  static func generateCompletionScript(_ type: ParsableCommand.Type) -> String {
    ToolInfoV0(commandStack: [type]).bashCompletionScript
  }
}

extension ToolInfoV0 {
  fileprivate var bashCompletionScript: String {
    // TODO: Add a check to see if the command is installed where we expect?
    """
      #!/bin/bash

      \(command.bashCompletionFunction)

      complete -F \(command.bashCompletionFunctionName) \(command.commandName)
      """
  }
}

extension CommandInfoV0 {
  private var bashCommandContext: [String] {
    (superCommands ?? []) + [commandName]
  }

  fileprivate var bashCompletionFunctionName: String {
    "_" + bashCommandContext.joined(separator: "_").makeSafeFunctionName
  }

  /// Generates a Bash completion function.
  fileprivate var bashCompletionFunction: String {
    let functionName = bashCompletionFunctionName

    // The root command gets a different treatment for the parsing index.
    let isRootCommand = (superCommands ?? []).count == 0
    let dollarOne = isRootCommand ? "1" : "$1"
    let subcommandArgument = isRootCommand ? "2" : "$(($1+1))"

    let subcommands = (subcommands ?? [])
      .filter { $0.shouldDisplay }

    // Generate the words that are available at the "top level" of this
    // command — these are the dash-prefixed names of options and flags as well
    // as all the subcommand names.
    let completionKeys = bashCompletionKeys + subcommands.map(\.commandName)

    // Generate additional top-level completions — these are completion lists
    // or custom function-based word lists from positional arguments.
    let additionalCompletions = bashPositionalCompletions

    // Start building the resulting function code.
    var result = "\(functionName)() {\n"

    // The function that represents the root command has some additional setup
    // that other command functions don't need.
    if isRootCommand {
      result += """
        export \(CompletionShell.shellEnvironmentVariableName)=bash
        \(CompletionShell.shellVersionEnvironmentVariableName)="$(IFS='.'; printf %s "${BASH_VERSINFO[*]}")"
        export \(CompletionShell.shellVersionEnvironmentVariableName)
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        COMPREPLY=()

        """.indentingEachLine(by: 4)
    }

    // Start by declaring a local var for the top-level completions.
    // Return immediately if the completion matching hasn't moved further.
    result += "    opts=\"\(completionKeys.joined(separator: " "))\"\n"
    for line in additionalCompletions {
      result += "    opts=\"$opts \(line)\"\n"
    }

    result += """
        if [[ $COMP_CWORD == "\(dollarOne)" ]]; then
            COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
            return
        fi

    """

    // Generate the case pattern-matching statements for option values.
    // If there aren't any, skip the case block altogether.
    let optionHandlers = bashOptionCompletions.joined(separator: "\n")
    if !optionHandlers.isEmpty {
      result += """
      case $prev in
      \(optionHandlers.indentingEachLine(by: 4))
      esac
      """.indentingEachLine(by: 4) + "\n"
    }

    // Build out completions for the subcommands.
    if !subcommands.isEmpty {
      // Subcommands have their own case statement that delegates out to
      // the subcommand completion functions.
      result += "    case ${COMP_WORDS[\(dollarOne)]} in\n"
      for subcommand in subcommands {
        result += """
          (\(subcommand.commandName))
              \(functionName)_\(subcommand.commandName) \(subcommandArgument)
              return
              ;;

          """
          .indentingEachLine(by: 8)
      }
      result += "    esac\n"
    }

    // Finish off the function.
    result += """
        COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
    }

    """

    return result +
      subcommands
      .map(\.bashCompletionFunction)
      .joined()
  }

  /// Returns the option and flag names that can be top-level completions.
  fileprivate var bashCompletionKeys: [String] {
    (arguments ?? []).flatMap(\.bashCompletionKeys)
  }

  /// Returns additional top-level completions from positional arguments.
  ///
  /// These consist of completions that are defined as `.list` or `.custom`.
  private var bashPositionalCompletions: [String] {
    (arguments ?? []).compactMap { argument in
      argument.shouldDisplay && argument.kind == .positional
      ? argument.bashPositionalCompletionValues(command: self)
      : nil
    }
  }

  /// Returns the case-matching statements for supplying completions after an option or flag.
  private var bashOptionCompletions: [String] {
    (arguments ?? []).compactMap { argument in
      guard argument.kind != .flag else { return nil }
      let keys = argument.bashCompletionKeys
      guard !keys.isEmpty else { return nil }
      return """
        \(keys.joined(separator: "|")))
        \(argument.bashOptionCompletionValues(command: self).indentingEachLine(by: 4))
            return
        ;;
        """
    }
  }
}

extension ArgumentInfoV0 {
  /// Returns the different completion names for this argument.
  fileprivate var bashCompletionKeys: [String] {
    shouldDisplay ? (names ?? []).map { $0.commonCompletionSynopsisString() } : []
  }

  // FIXME: determine if this can be combined with bashOptionCompletionValues
  fileprivate func bashPositionalCompletionValues(
    command: CommandInfoV0
  ) -> String? {
    precondition(kind == .positional)

    switch completionKind {
    case .none, .file, .directory:
      // FIXME: this doesn't work
      return nil
    case .list(let list):
      return list.joined(separator: " ")
    case .shellCommand(let command):
      return "$(\(command))"
    case .custom:
      // Generate a call back into the command to retrieve a completions list
      return #"$("${COMP_WORDS[0]}" \#(commonCustomCompletionCall(command: command)) "${COMP_WORDS[@]}")"#
    }
  }

  /// Returns the bash completions that can follow this argument's `--name`.
  ///
  /// Uses bash-completion for file and directory values if available.
  fileprivate func bashOptionCompletionValues(
    command: CommandInfoV0
  ) -> String {
    precondition(kind == .option)

    switch completionKind {
    case .none:
      return ""

    case .file(let extensions) where extensions.isEmpty:
      return """
        if declare -F _filedir >/dev/null; then
          _filedir
        else
          COMPREPLY=( $(compgen -f -- "$cur") )
        fi
        """

    case .file(let extensions):
      var safeExts = extensions.map { String($0.flatMap { $0 == "'" ? ["\\", "'"] : [$0] }) }
      safeExts.append(contentsOf: safeExts.map { $0.uppercased() })

      return """
        if declare -F _filedir >/dev/null; then
          \(safeExts.map { "_filedir '\($0)'" }.joined(separator:"\n  "))
          _filedir -d
        else
          COMPREPLY=(
            \(safeExts.map { "$(compgen -f -X '!*.\($0)' -- \"$cur\")" }.joined(separator: "\n    "))
            $(compgen -d -- "$cur")
          )
        fi
        """

    case .directory:
      return """
        if declare -F _filedir >/dev/null; then
          _filedir -d
        else
          COMPREPLY=( $(compgen -d -- "$cur") )
        fi
        """

    case .list(let list):
      return #"COMPREPLY=( $(compgen -W "\#(list.joined(separator: " "))" -- "$cur") )"#

    case .shellCommand(let command):
      return "COMPREPLY=( $(\(command)) )"

    case .custom:
      // Generate a call back into the command to retrieve a completions list
      return #"COMPREPLY=( $(compgen -W "$("${COMP_WORDS[0]}" \#(commonCustomCompletionCall(command: command)) "${COMP_WORDS[@]}")" -- "$cur") )"#
    }
  }
}
