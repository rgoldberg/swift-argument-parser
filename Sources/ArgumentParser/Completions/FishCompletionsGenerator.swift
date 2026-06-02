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

internal import ArgumentParserToolInfo

extension ToolInfoV0 {
  var fishCompletionScript: String {
    command.fishCompletionScript
  }
}

extension CommandInfoV0 {
  fileprivate var fishCompletionScript: String {
    """
    function \(completeFunctionName(kind: .flag)) -a expected_commands expected_flags description
        complete -c '\(commandName)' -n "\(shouldOfferCompletionsForFlagsOrOptionValuesFunctionName) '$expected_commands' '$expected_flags'" (test -n "$description" && printf '-d %s' $description) -fa "$expected_flags"
    end

    function \(completeFunctionName(kind: .option)) -a expected_commands expected_options
        \(completeFunctionName(kind: .flag)) $argv
        complete -c '\(commandName)' -n "\(shouldOfferCompletionsForFlagsOrOptionValuesFunctionName) '$expected_commands' '$expected_options' 'contains -- \\"\\$option\\" (string split -n \\\\' \\\\' -- \\$expected_options)'" $argv[4..-1]
    end

    function \(shouldOfferCompletionsForFlagsOrOptionValuesFunctionName) -a expected_commands expected_options option_check
        set -l flags (string split -n ' ' -- $expected_options)
        if test -z "$option_check"
            set option_check true
            set non_repeating_flags _flag_(string replace -a - _ -- (string trim -lc - -- $flags))
        else
            set non_repeating_flags
        end
        set -l non_repeating_flags_absent 0
        set -l positional_index 0
        set -l option
        set -l commands
        set -l positional_count 0
        set -l is_repeating false
        \(parseTokensFunctionName)
        test "$status" -eq 0 -a "$commands" = "$expected_commands" -a "$non_repeating_flags_absent" -eq 0 && eval $option_check
    end

    function \(shouldOfferCompletionsForPositionalFunctionName) -a expected_commands expected_positional_index
        set -l non_repeating_flags
        set -l non_repeating_flags_absent 0
        set -l positional_index 0
        set -l expected_options
        set -l option
        set -l commands
        set -l positional_count 0
        set -l is_repeating false
        \(parseTokensFunctionName)
        test "$status" -eq 0 -a "$commands" = "$expected_commands"; or return 1
        if test "$is_repeating" = true -a "$expected_positional_index" -eq "$positional_count"
            test "$positional_index" -ge "$expected_positional_index"
        else
            test "$positional_index" -eq "$expected_positional_index"
        end
    end

    function \(parseTokensFunctionName) -S
        set -l unparsed_tokens (\(tokensFunctionName) -pc)
        switch $unparsed_tokens[1]
    \(commandCases)
        end
    end

    function \(tokensFunctionName)
        set -l fish_version (string split -m 2 -f 1,2 -- . "$FISH_VERSION")
        if test $fish_version[1] -gt 4; or test $fish_version[1] -eq 4 -a $fish_version[2] -ge 1
            set -f tokenize --tokenize-raw
        else
            set -f tokenize -t
        end

        eval "function \(tokensFunctionName)
            commandline \\$argv | read $tokenize -la tokens
            printf %s\\n \\$tokens
        end"

        \(tokensFunctionName) $argv
    end

    function \(parseSubcommandFunctionName) -Sa expected_positional_count expected_is_repeating
        set -a commands $unparsed_tokens[1]
        set positional_index 0
        set positional_count $expected_positional_count
        set is_repeating $expected_is_repeating
        set -l option_specs $argv[3..]
        while true
            set -e unparsed_tokens[1]
            argparse -sn "$commands" $option_specs -- $unparsed_tokens 2>| read -l argparse_error
            if test -z "$argparse_error"
                set unparsed_tokens $argv
                set positional_index (math $positional_index + 1)
            else if string match -q '*: option requires an argument' -- $argparse_error
                set option "$unparsed_tokens[-1]"
                if not contains -- "$option" $flags
                    return 1
                end
                set _flag_(string replace -a - _ -- (string trim -lc - -- $option)) $option
                argparse -sn "$commands" $option_specs -- $unparsed_tokens[..-2] || return
                set unparsed_tokens $argv
            else
                return 1
            end
            for non_repeating_flag in $non_repeating_flags
                if set -q -- "$non_repeating_flag"
                    set non_repeating_flags_absent 1
                    break
                end
            end
            test (count $unparsed_tokens) -eq 0 -o \\( "$is_repeating" != true -a "$positional_index" -gt "$positional_count" \\) && return
        end
    end

    function \(completeDirectoriesFunctionName)
        set -l token (commandline -t)
        string match -- '*/' $token
        set -l subdirs $token*/
        printf %s\\n $subdirs
    end

    function \(customCompletionFunctionName)
        set -x \(Platform.Environment.Key.shellName.rawValue) fish
        set -x \(Platform.Environment.Key.shellVersion.rawValue) $FISH_VERSION
        set -l tokens (\(tokensFunctionName) -p)
        if test -z "$(\(tokensFunctionName) -t)"
            set -l index (count (\(tokensFunctionName) -pc))
            set tokens $tokens[..$index] \\'\\' $tokens[(math $index + 1)..]
        end
        command $tokens[1] $argv $tokens
    end

    complete -c '\(commandName)' -f
    \(completions.joined(separator: "\n"))
    """
  }

  private var commandCases: String {
    let subcommands = (subcommands ?? []).filter(\.shouldDisplay)
    return """
      case '\(commandName)'
          \(parseSubcommandFunctionName) \(positionalArgumentCountArguments) \(
            completableArguments
            .compactMap(\.optionSpec)
            .map { "'\($0.fishEscapeForSingleQuotedString())'" }
            .joined(separator: separator)
          ) || return\(
            subcommands.isEmpty
              ? ""
              : """

                  switch $unparsed_tokens[1]
              \(subcommands.map(\.commandCases).joined(separator: "\n"))
                  end
              """
          )
      """
      .indentingEachLine(by: 4)
  }

  private var completions: [String] {
    let prefix = "complete -c '\(initialCommand)' -n '"
    let subcommands = (subcommands ?? []).filter(\.shouldDisplay)
    var positionalIndex = 0
    let argumentCompletions =
      completableArguments
      .compactMap { arg in
        """
        \(
          arg.kind == .positional
          ? """
          \(prefix)\(shouldOfferCompletionsForPositionalFunctionName) "\(commandContext.joined(separator: separator))"\
           \({
            positionalIndex += 1
            return positionalIndex
          }())'
          """
          : """
            \(completeFunctionName(kind: arg.kind)) '\(commandContext.joined(separator: separator))'\
             '\((arg.names ?? []).map { $0.commonCompletionSynopsisString() }.joined(separator: " "))'
            """
        ) \(argumentSegments(arg).joined(separator: separator))
        """
      }

    positionalIndex += 1

    return
      argumentCompletions
      + subcommands.map {
        """
        \(prefix)\(shouldOfferCompletionsForPositionalFunctionName) "\(commandContext.joined(separator: separator))"\
         \(positionalIndex)' -fa '\($0.commandName)' -d '\($0.abstract?.fishEscapeForSingleQuotedString() ?? "")'
        """
      }
      + subcommands.flatMap(\.completions)
  }

  private var completableArguments: [ArgumentInfoV0] {
    (arguments ?? []).filter { arg in
      arg.shouldDisplay
        && (arg.completionKind != nil || arg.names?.isEmpty == false)
    }
  }

  private func argumentSegments(_ arg: ArgumentInfoV0) -> [String] {
    let completions =
      switch arg.completionKind {
      case .none:
        switch arg.kind {
        case .positional,
          .option:
          "-fka ''"
        default:
          String?.none
        }
      case .list(let list):
        "-fka '\(list.joined(separator: separator))'"
      case .file(let extensions):
        switch extensions.count {
        case 0:
          "-F"
        case 1:
          """
          -fa '(\
          for p in (string match -e -- \\'*/\\' (commandline -t);or printf \\n)*.\\'\(extensions.map { $0.fishEscapeForSingleQuotedString(iterationCount: 2) }.joined())\\';printf %s\\n $p;end;\
          __fish_complete_directories (commandline -t) \\'\\'\
          )'
          """
        default:
          """
          -fa '(\
          set -l exts \(extensions.map { "\\'\($0.fishEscapeForSingleQuotedString(iterationCount: 2))\\'" }.joined(separator: separator));\
          for p in (string match -e -- \\'*/\\' (commandline -t);or printf \\n)*.{$exts};printf %s\\n $p;end;\
          __fish_complete_directories (commandline -t) \\'\\'\
          )'
          """
        }
      case .directory:
        "-fa '(\(completeDirectoriesFunctionName))'"
      case .shellCommand(let shellCommand):
        "-fka '(\(shellCommand.fishEscapeForSingleQuotedString()))'"
      case .custom, .customAsync:
        """
        -fka '(\
        \(customCompletionFunctionName) \(arg.commonCustomCompletionCall(command: self)) \
        (count (\(tokensFunctionName) -pc)) (\(tokensFunctionName) -tC)\
        )'
        """
      case .customDeprecated:
        "-fka '(\(customCompletionFunctionName) \(arg.commonCustomCompletionCall(command: self)))'"
      }
    return [
      arg.kind == .positional
        ? nil
        : "'\(arg.abstract?.fishEscapeForSingleQuotedString() ?? "")'",
      completions,
    ]
    .compactMap(\.self)
  }

  var positionalArgumentCountArguments: String {
    let positionalArguments = positionalArguments
    return """
      \(positionalArguments.count) \(positionalArguments.contains(where: { $0.isRepeating }) ? "true" : "false")
      """
  }

  private func completeFunctionName(kind: ArgumentInfoV0.KindV0) -> String {
    "\(completionFunctionPrefix)_complete_\(kind)"
  }

  private var shouldOfferCompletionsForFlagsOrOptionValuesFunctionName: String {
    "\(completionFunctionPrefix)_should_offer_completions_for_flags_or_option_values"
  }

  private var shouldOfferCompletionsForPositionalFunctionName: String {
    "\(completionFunctionPrefix)_should_offer_completions_for_positional"
  }

  private var parseTokensFunctionName: String {
    "\(completionFunctionPrefix)_parse_tokens"
  }

  private var tokensFunctionName: String {
    "\(completionFunctionPrefix)_tokens"
  }

  private var parseSubcommandFunctionName: String {
    "\(completionFunctionPrefix)_parse_subcommand"
  }

  private var completeDirectoriesFunctionName: String {
    "\(completionFunctionPrefix)_complete_directories"
  }

  private var customCompletionFunctionName: String {
    "\(completionFunctionPrefix)_custom_completion"
  }
}

extension ArgumentInfoV0 {
  fileprivate var optionSpec: String? {
    name(.short).map { shortName in
      name(.long).map { optionSpecRequiresValue("\(shortName)/\($0)") }
        ?? optionSpecRequiresValue(shortName)
    }
      ?? name(.long).map(optionSpecRequiresValue(_:))
  }

  private func name(_ nameKind: NameInfoV0.KindV0) -> String? {
    (names ?? []).first(where: { $0.kind == nameKind })?.name
  }

  private func optionSpecRequiresValue(_ optionSpec: String) -> String {
    kind == .option ? "\(optionSpec)=\(isRepeating ? "+" : "")" : optionSpec
  }
}

extension String {
  fileprivate func fishEscapeForSingleQuotedString(
    iterationCount: UInt64 = 1
  ) -> Self {
    iterationCount == 0
      ? self
      : replacing("\\", with: "\\\\")
        .replacing("'", with: "\\'")
        .fishEscapeForSingleQuotedString(iterationCount: iterationCount - 1)
  }
}

private let separator = " "
