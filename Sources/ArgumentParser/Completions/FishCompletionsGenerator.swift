//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

extension [ParsableCommand.Type] {
  var fishCompletionScript: String {
    """
    # A function which filters options which starts with "-" from $argv.
    function \(commandsAndPositionalsFunctionName)
        set -l results
        for i in (seq (count $argv))
            switch (echo $argv[$i] | string sub -l 1)
                case '-'
                case '*'
                    echo $argv[$i]
            end
        end
    end

    function \(usingCommandFunctionName)
        set -gx \(CompletionShell.shellEnvironmentVariableName) fish
        set -gx \(CompletionShell.shellVersionEnvironmentVariableName) "$FISH_VERSION"
        set -l commands_and_positionals (\(commandsAndPositionalsFunctionName) (commandline -opc))
        set -l expected_commands (string split -- '\(separator)' $argv[1])
        set -l subcommands (string split -- '\(separator)' $argv[2])
        if [ (count $commands_and_positionals) -ge (count $expected_commands) ]
            for i in (seq (count $expected_commands))
                if [ $commands_and_positionals[$i] != $expected_commands[$i] ]
                    return 1
                end
            end
            if [ (count $commands_and_positionals) -eq (count $expected_commands) ]
                return 0
            end
            if [ (count $subcommands) -gt 1 ]
                for i in (seq (count $subcommands))
                    if [ $commands_and_positionals[(math (count $expected_commands) + 1)] = $subcommands[$i] ]
                        return 1
                    end
                end
            end
            return 0
        end
        return 1
    end

    \(completions.joined(separator: "\n"))
    """
  }

  private var completions: [String] {
    guard let type = last else {
      fatalError()
    }
    var subcommands = type.configuration.subcommands
      .filter { $0.configuration.shouldDisplay }

    if count == 1 {
      subcommands.addHelpSubcommandIfMissing()
    }

    // swift-format-ignore: NeverForceUnwrap
    // Precondition: first is guaranteed to be non-empty
    let commandName = first!._commandName
    var prefix = """
      complete -c \(commandName)\
       -n '\(usingCommandFunctionName)\
       "\(map { $0._commandName }.joined(separator: separator))"
      """
    if !subcommands.isEmpty {
      prefix +=
        " \"\(subcommands.map { $0._commandName }.joined(separator: separator))\""
    }
    prefix += "'"

    func complete(suggestion: String) -> String {
      "\(prefix) \(suggestion)"
    }

    let subcommandCompletions: [String] = subcommands.map { subcommand in
      complete(
        suggestion:
          "-fa '\(subcommand._commandName)' -d '\(subcommand.configuration.abstract.fishEscapeForSingleQuotedString())'"
      )
    }

    let argumentCompletions =
      argumentsForHelp(visibility: .default)
      .compactMap { argumentSegments($0) }
      .map { $0.joined(separator: separator) }
      .map { complete(suggestion: $0) }

    let completionsFromSubcommands = subcommands.flatMap { subcommand in
      (self + [subcommand]).completions
    }

    return
      completionsFromSubcommands + argumentCompletions + subcommandCompletions
  }

  private func argumentSegments(_ arg: ArgumentDefinition) -> [String]? {
    guard arg.help.visibility.base == .default
    else { return nil }

    var results: [String] = []

    if !arg.names.isEmpty {
      results += arg.names.map { $0.asFishSuggestion }
    }

    if !arg.help.abstract.isEmpty {
      results += ["-d '\(arg.help.abstract.fishEscapeForSingleQuotedString())'"]
    }

    switch arg.completion.kind {
    case .default where arg.names.isEmpty:
      return nil
    case .default:
      break
    case .list(let list):
      results += ["-rfka '\(list.joined(separator: separator))'"]
    case .file(let extensions):
      let pattern = "*.{\(extensions.joined(separator: ","))}"
      results += ["-rfa '(for i in \(pattern); echo $i;end)'"]
    case .directory:
      results += ["-rfa '(__fish_complete_directories)'"]
    case .shellCommand(let shellCommand):
      results += ["-rfa '(\(shellCommand))'"]
    case .custom:
      // swift-format-ignore: NeverForceUnwrap
      // Precondition: first is guaranteed to be non-empty
      results += [
        "-rfa '(command \(first!._commandName) \(arg.customCompletionCall(self)) (commandline -opc)[1..-1])'"
      ]
    }

    return results
  }

  private var commandsAndPositionalsFunctionName: String {
    // swift-format-ignore: NeverForceUnwrap
    // Precondition: first is guaranteed to be non-empty
    "_swift_\(first!._commandName)_commands_and_positionals"
  }

  private var usingCommandFunctionName: String {
    // swift-format-ignore: NeverForceUnwrap
    // Precondition: first is guaranteed to be non-empty
    "_swift_\(first!._commandName)_using_command"
  }
}

extension Name {
  fileprivate var asFishSuggestion: String {
    switch self {
    case .long(let longName):
      return "-l \(longName)"
    case .short(let shortName, _):
      return "-s \(shortName)"
    case .longWithSingleDash(let dashedName):
      return "-o \(dashedName)"
    }
  }
}

extension String {
  fileprivate func fishEscapeForSingleQuotedString(
    iterationCount: UInt64 = 1
  ) -> Self {
    iterationCount == 0
      ? self
      : replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "'", with: "\\'")
        .fishEscapeForSingleQuotedString(iterationCount: iterationCount - 1)
  }
}

private var separator: String { " " }
