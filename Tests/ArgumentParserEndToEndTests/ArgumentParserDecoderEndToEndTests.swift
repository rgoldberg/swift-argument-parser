//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import ArgumentParserTestHelpers
import Testing

@Suite struct ArgumentParserDecoderEndToEndTests {}

/// What an `ArgumentParserDecoder` reports while it decodes a type.
private struct Report: Equatable {
  var commandStack: [String] = []
  var sources: [String: ArgumentValueSource] = [:]
  var names: [String: String] = [:]

  init() {}

  init(_ decoder: any Decoder, keys: [some CodingKey]) throws {
    let decoder = try #require(decoder as? any ArgumentParserDecoder)
    commandStack = decoder.commandStack
    for key in keys {
      sources[key.stringValue] = decoder.valueSource(forKey: key)
      names[key.stringValue] = decoder.argumentName(forKey: key)
    }
  }
}

private struct Group: ParsableArguments {
  enum CodingKeys: CodingKey {
    case color
  }

  @Option var color = "red"

  var report = Report()

  init() {}

  init(from decoder: any Decoder) throws {
    // ArgumentParser validates a type by checking that its `init(from:)` first
    // obtains a keyed container
    let container = try decoder.container(keyedBy: CodingKeys.self)
    report = try Report(decoder, keys: [CodingKeys.color])
    _color = try container.decode(Option<String>.self, forKey: .color)
  }
}

private struct Root: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "root", subcommands: [Sub.self])

  enum CodingKeys: CodingKey {
    case verbose
  }

  @Flag var verbose = false

  var report = Report()

  init() {}

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    report = try Report(decoder, keys: [CodingKeys.verbose])
    _verbose = try container.decode(Flag<Bool>.self, forKey: .verbose)
  }
}

private struct Sub: ParsableCommand {
  enum CodingKeys: CodingKey {
    case country
    case downloadLimit
    case outputDirectory
    case quiet
    case target
    case appIDs
    case group
  }

  @Option var country: String
  @Option(name: [.customShort("m"), .customLong("max"), .long])
  var downloadLimit = 4
  @Option var outputDirectory: String?
  @Flag(name: .short) var quiet = false
  @Argument var target: String?
  @Argument(help: .init(valueName: "app-id")) var appIDs: [Int] = []
  @OptionGroup var group: Group

  var report = Report()

  init() {}

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let report = try Report(
      decoder,
      keys: [
        CodingKeys.country, .downloadLimit, .outputDirectory, .quiet, .target,
        .appIDs,
      ])
    self.report = report
    // An external source supplies each value that the command line did not.
    func wrapper<Wrapper: Decodable & ExternallyDefaultable>(
      forKey key: CodingKeys, externalDefault: Wrapper.Value
    ) throws -> Wrapper {
      report.sources[key.stringValue] == .commandLine
        ? try container.decode(Wrapper.self, forKey: key)
        : Wrapper(externalDefault: externalDefault)
    }
    _country = try wrapper(forKey: .country, externalDefault: "CA")
    _downloadLimit = try wrapper(forKey: .downloadLimit, externalDefault: 9)
    _outputDirectory = try wrapper(
      forKey: .outputDirectory, externalDefault: "/tmp")
    _quiet = try wrapper(forKey: .quiet, externalDefault: true)
    _appIDs = try wrapper(forKey: .appIDs, externalDefault: [1, 2])
    _target = try wrapper(forKey: .target, externalDefault: "a")
    _group = try container.decode(OptionGroup<Group>.self, forKey: .group)
  }
}

extension ArgumentParserDecoderEndToEndTests {
  @Test func commandStack() throws {
    let root = try #require(try Root.parseAsRoot([]) as? Root)
    #expect(root.report.commandStack == ["root"])

    let sub = try #require(try Root.parseAsRoot(["sub"]) as? Sub)
    #expect(sub.report.commandStack == ["root", "sub"])
    #expect(sub.group.report.commandStack == ["root", "sub"])
  }

  @Test func valueSource() throws {
    let unsupplied = try #require(try Root.parseAsRoot(["sub"]) as? Sub)
    #expect(
      unsupplied.report.sources == [
        "country": .missing,
        "downloadLimit": .defaultValue,
        "outputDirectory": .defaultValue,
        "quiet": .defaultValue,
        "appIDs": .defaultValue,
        "target": .defaultValue,
      ])
    #expect(unsupplied.group.report.sources == ["color": .defaultValue])

    let supplied = try #require(
      try Root.parseAsRoot([
        "sub", "--country", "US", "-m", "7", "--output-directory", "/out",
        "-q", "--color", "blue", "t", "5",
      ]) as? Sub)
    #expect(
      supplied.report.sources == [
        "country": .commandLine,
        "downloadLimit": .commandLine,
        "outputDirectory": .commandLine,
        "quiet": .commandLine,
        "appIDs": .commandLine,
        "target": .commandLine,
      ])
    #expect(supplied.group.report.sources == ["color": .commandLine])
  }

  @Test func argumentName() throws {
    let sub = try #require(try Root.parseAsRoot(["sub"]) as? Sub)
    #expect(
      sub.report.names == [
        "country": "country",
        "downloadLimit": "max",
        "outputDirectory": "output-directory",
        "quiet": "q",
        "appIDs": "app-id",
        "target": "target",
      ])
    #expect(sub.group.report.names == ["color": "color"])
  }

  @Test func externalDefault() throws {
    let unsupplied = try #require(try Root.parseAsRoot(["sub"]) as? Sub)
    #expect(unsupplied.country == "CA")
    #expect(unsupplied.downloadLimit == 9)
    #expect(unsupplied.outputDirectory == "/tmp")
    #expect(unsupplied.quiet)
    #expect(unsupplied.target == "a")
    #expect(unsupplied.appIDs == [1, 2])

    let supplied = try #require(
      try Root.parseAsRoot([
        "sub", "--country", "US", "--max", "7", "--output-directory", "/out",
        "t", "5",
      ]) as? Sub)
    #expect(supplied.country == "US")
    #expect(supplied.downloadLimit == 7)
    #expect(supplied.outputDirectory == "/out")
    // The command line did not supply `-q`.
    #expect(supplied.quiet)
    #expect(supplied.target == "t")
    #expect(supplied.appIDs == [5])
  }
}

// MARK: - ExternallyDefaulted

extension Group: ExternallyDefaulted {
  static func externalDefault(
    forPropertyNamed propertyName: String,
    argumentName: String,
    commandStack: [String]
  ) -> ExternalDefault? {
    propertyName == "color"
      ? ExternalDefault(
        value: (commandStack + [argumentName]).joined(separator: "."))
      : nil
  }
}

extension Sub: ExternallyDefaulted {
  static func externalDefault(
    forPropertyNamed propertyName: String,
    argumentName: String,
    commandStack: [String]
  ) -> ExternalDefault? {
    switch propertyName {
    case "country":
      // A secret value is not shown.
      ExternalDefault(value: nil)
    case "downloadLimit":
      ExternalDefault(value: 9)
    case "quiet":
      ExternalDefault(value: true)
    case "appIDs":
      ExternalDefault(value: [1, 2])
    default:
      nil
    }
  }
}

private struct Plain: ParsableArguments {
  @Option var size = "m"
}

private struct Point {
  var x: Int

  init(_ argument: String) throws {
    x = try #require(Int(argument))
  }
}

/// A command that returns an external default value for every property that
/// it is asked about.
private struct Flags: ParsableCommand, ExternallyDefaulted {
  @Flag(inversion: .prefixedNo) var color: Bool
  @Flag(inversion: .prefixedNo) var sound = true
  @Flag var loud = false
  @Flag var shape: Shape
  @Option(transform: Point.init) var point: Point
  @OptionGroup var plain: Plain

  static func externalDefault(
    forPropertyNamed propertyName: String,
    argumentName: String,
    commandStack: [String]
  ) -> ExternalDefault? {
    switch propertyName {
    case "color", "sound", "loud":
      ExternalDefault(value: false)
    case "shape":
      ExternalDefault(value: Shape.square)
    case "point":
      try? ExternalDefault(value: Point("1"))
    default:
      ExternalDefault(value: "\(propertyName).\(argumentName)")
    }
  }
}

extension ArgumentParserDecoderEndToEndTests {
  @Test func externalDefaultHelp() {
    // `--country` is no longer required, but its secret value is not shown.
    #expect(
      Root.helpMessage(for: Sub.self) == """
        USAGE: root sub [--country <country>] [--max <max>] [--output-directory <output-directory>] [-q] [<target>] [<app-id> ...] [--color <color>]

        ARGUMENTS:
          <target>
          <app-id>                (default: 1, 2)

        OPTIONS:
          --country <country>
          -m, --max, --download-limit <max>
                                  (default: 9)
          --output-directory <output-directory>
          -q                      (default: true)
          --color <color>         (default: root.sub.color)
          -h, --help              Show help information.

        """)
  }

  @Test func externalDefaultHelpForFlags() {
    // A flag is described by the name that gives its value, a value that is
    // not `ExpressibleByArgument` is not described, and the property of an
    // option group is not that of the type that includes it.
    #expect(
      Flags.helpMessage() == """
        USAGE: flags [--color] [--no-color] [--sound] [--no-sound] [--loud] [--round] [--square] [--oblong] [--point <point>] [--size <size>]

        OPTIONS:
          --color/--no-color      (default: --no-color)
          --sound/--no-sound      (default: --no-sound)
          --loud
          --round/--square/--oblong
                                  (default: --square)
          --point <point>
          --size <size>           (default: m)
          -h, --help              Show help information.

        """)
  }
}
