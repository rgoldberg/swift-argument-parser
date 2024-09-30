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

/// The configuration for a command.
public struct CommandConfiguration: Sendable {
  /// The name of the command to use on the command line.
  ///
  /// If `nil`, the command name is derived by converting the name of
  /// the command type to hyphen-separated lowercase words.
  public var commandName: String?

  /// The name of this command's "super-command". (experimental)
  ///
  /// Use this when a command is part of a group of commands that are installed
  /// with a common dash-prefix, like `git`'s and `swift`'s constellation of
  /// independent commands.
  public var _superCommandName: String?

  /// A one-line description of this command.
  public var abstract: String

  /// A customized usage string to be shown in the help display and error
  /// messages.
  ///
  /// If `usage` is `nil`, the help display and errors show the autogenerated
  /// usage string. To hide the usage string entirely, set `usage` to the empty
  /// string.
  public var usage: String?

  /// A longer description of this command, to be shown in the extended help
  /// display.
  ///
  /// Can include specific abstracts about the argument's possible values (e.g.
  /// for a custom `EnumerableOptionValue` type), or can describe
  /// a static block of text that extends the description of the argument.
  public var discussion: String

  /// Version information for this command.
  public var version: String

  /// A Boolean value indicating whether this command should be shown in
  /// the extended help display.
  public var shouldDisplay: Bool

  /// An array of the types that define subcommands for this command.
  ///
  /// This property "flattens" the grouping structure of the subcommands.
  /// Use 'ungroupedSubcommands' to access 'groupedSubcommands' to retain the grouping structure.
  public var subcommands: [ParsableCommand.Type] {
    get {
      return ungroupedSubcommands + groupedSubcommands.flatMap { $0.subcommands }
    }

    set {
      groupedSubcommands = []
      ungroupedSubcommands = newValue
    }
  }

  /// An array of types that define subcommands for this command and are
  /// not part of any command group.
  public var ungroupedSubcommands: [ParsableCommand.Type]

  /// The list of subcommands and subcommand groups.
  public var groupedSubcommands: [CommandGroup]

  /// The default command type to run if no subcommand is given.
  public var defaultSubcommand: ParsableCommand.Type?

  /// Flag names to be used for help.
  public var helpNames: NameSpecification?

  /// An array of aliases for the command's name.
  ///
  /// All of the aliases MUST not match the actual command's name,
  /// whether that be the derived name if `commandName` is not provided,
  /// or `commandName` itself if provided.
  public var aliases: [String]

  /// Creates the configuration for a command.
  ///
  /// - Parameters:
  ///   - commandName: The name of the command to use on the command line. If
  ///     `commandName` is `nil`, the command name is derived by converting
  ///     the name of the command type to hyphen-separated lowercase words.
  ///   - abstract: A one-line description of the command.
  ///   - usage: A custom usage description for the command. When you provide
  ///     a non-`nil` string, the argument parser uses `usage` instead of
  ///     automatically generating a usage description. Passing an empty string
  ///     hides the usage string altogether.
  ///   - discussion: A longer description of the command.
  ///   - version: The version number for this command. When you provide a
  ///     non-empty string, the argument parser prints it if the user provides
  ///     a `--version` flag.
  ///   - shouldDisplay: A Boolean value indicating whether the command
  ///     should be shown in the extended help display.
  ///   - ungroupedSubcommands: An array of the types that define subcommands
  ///     for the command that are not part of any command group.
  ///   - groupedSubcommands: An array of command groups, each of which defines
  ///     subcommands that are part of that logical group.
  ///   - defaultSubcommand: The default command type to run if no subcommand
  ///     is given.
  ///   - helpNames: The flag names to use for requesting help, when combined
  ///     with a simulated Boolean property named `help`. If `helpNames` is
  ///     `nil`, the names are inherited from the parent command, if any, or
  ///     are `-h` and `--help`.
  ///   - aliases: An array of aliases for the command's name. All of the aliases
  ///     MUST not match the actual command name, whether that be the derived name
  ///     if `commandName` is not provided, or `commandName` itself if provided.
  public init(
    commandName: String? = nil,
    abstract: String = "",
    usage: String? = nil,
    discussion: String = "",
    version: String = "",
    shouldDisplay: Bool = true,
    subcommands ungroupedSubcommands: [ParsableCommand.Type] = [],
    groupedSubcommands: [CommandGroup] = [],
    defaultSubcommand: ParsableCommand.Type? = nil,
    helpNames: NameSpecification? = nil,
    aliases: [String] = []
  ) {
    self.commandName = commandName
    self.abstract = abstract
    self.usage = usage
    self.discussion = discussion
    self.version = version
    self.shouldDisplay = shouldDisplay
    self.ungroupedSubcommands = ungroupedSubcommands
    self.groupedSubcommands = groupedSubcommands
    self.defaultSubcommand = defaultSubcommand
    self.helpNames = helpNames
    self.aliases = aliases
  }

  /// Creates the configuration for a command with a "super-command".
  /// (experimental)
  public init(
    commandName: String? = nil,
    _superCommandName: String,
    abstract: String = "",
    usage: String? = nil,
    discussion: String = "",
    version: String = "",
    shouldDisplay: Bool = true,
    subcommands ungroupedSubcommands: [ParsableCommand.Type] = [],
    groupedSubcommands: [CommandGroup] = [],
    defaultSubcommand: ParsableCommand.Type? = nil,
    helpNames: NameSpecification? = nil,
    aliases: [String] = []
  ) {
    self.commandName = commandName
    self._superCommandName = _superCommandName
    self.abstract = abstract
    self.usage = usage
    self.discussion = discussion
    self.version = version
    self.shouldDisplay = shouldDisplay
    self.ungroupedSubcommands = ungroupedSubcommands
    self.groupedSubcommands = groupedSubcommands
    self.defaultSubcommand = defaultSubcommand
    self.helpNames = helpNames
    self.aliases = aliases
  }
}

extension CommandConfiguration {
  @available(*, deprecated, message: "Use the memberwise initializer with the aliases parameter.")
  public init(
    commandName _commandName: String?,
    abstract: String,
    usage: String?,
    discussion: String,
    version: String,
    shouldDisplay: Bool,
    subcommands: [ParsableCommand.Type],
    defaultSubcommand: ParsableCommand.Type?,
    helpNames: NameSpecification?
  ) {
    self.init(
      commandName: _commandName,
      abstract: abstract,
      usage: usage,
      discussion: discussion,
      version: version,
      shouldDisplay: shouldDisplay,
      subcommands: subcommands,
      defaultSubcommand: defaultSubcommand,
      helpNames: helpNames,
      aliases: [])
  }

  @available(*, deprecated, message: "Use the memberwise initializer with the usage and aliases parameters.")
  public init(
    commandName _commandName: String?,
    abstract: String,
    discussion: String,
    version: String,
    shouldDisplay: Bool,
    subcommands: [ParsableCommand.Type],
    defaultSubcommand: ParsableCommand.Type?,
    helpNames: NameSpecification?
  ) {
    self.init(
      commandName: _commandName,
      abstract: abstract,
      usage: "",
      discussion: discussion,
      version: version,
      shouldDisplay: shouldDisplay,
      subcommands: subcommands,
      defaultSubcommand: defaultSubcommand,
      helpNames: helpNames,
      aliases: [])
  }
}
