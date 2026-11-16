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

// MARK: - Parsed external defaults

private enum Tone: EnumerableFlag {
  case warm
  case cool
  case dim
}

/// A command that obtains the external default value of each property by
/// having ArgumentParser parse arguments.
private struct Parsed: ParsableCommand, ExternallyDefaulted {
  enum CodingKeys: String, CodingKey, CaseIterable {
    case shape
    case tones
    case point
    case points
    case color
    case sound
    case size
  }

  static let arguments = [
    "shape": ["square"],
    "tones": ["dim", "warm"],
    "point": ["3"],
    "points": ["4", "5"],
    "color": ["no-color"],
    "sound": ["disable-sound"],
    // Invalid, so `size` has no external default value.
    "size": ["x"],
  ]

  @Flag var shape: Shape
  @Flag var tones: [Tone] = []
  @Option(transform: Point.init) var point: Point
  @Option(transform: Point.init) var points: [Point] = []
  @Flag(inversion: .prefixedNo) var color = true
  @Flag(inversion: .prefixedEnableDisable) var sound = true
  @Option var size = 1

  var names: [String: String] = [:]

  init() {}

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let decoder = try #require(decoder as? any ArgumentParserDecoder)
    for key in CodingKeys.allCases {
      names[key.stringValue] = decoder.argumentName(forKey: key)
    }
    func wrapper<Wrapper: Decodable & ExternallyDefaultable>(
      forKey key: CodingKeys
    ) throws -> Wrapper {
      let value =
        decoder.valueSource(forKey: key) == .commandLine
        ? nil
        : try? decoder.value(
          forKey: key, parsing: Self.arguments[key.stringValue] ?? [])
      return try (value as? Wrapper.Value).map(Wrapper.init(externalDefault:))
        ?? container.decode(Wrapper.self, forKey: key)
    }
    _shape = try wrapper(forKey: .shape)
    _tones = try wrapper(forKey: .tones)
    _point = try wrapper(forKey: .point)
    _points = try wrapper(forKey: .points)
    _color = try wrapper(forKey: .color)
    _sound = try wrapper(forKey: .sound)
    _size = try wrapper(forKey: .size)
  }

  static func externalDefault(
    forPropertyNamed propertyName: String,
    argumentName: String,
    commandStack: [String]
  ) -> ExternalDefault? {
    arguments[propertyName].map {
      // A secret value is not shown.
      ExternalDefault(arguments: $0, isValueShown: propertyName != "color")
    }
  }
}

extension ArgumentParserDecoderEndToEndTests {
  @Test func parsedExternalDefault() throws {
    let unsupplied = try Parsed.parse([])
    #expect(unsupplied.shape == .square)
    #expect(unsupplied.tones == [.dim, .warm])
    #expect(unsupplied.point.x == 3)
    #expect(unsupplied.points.map(\.x) == [4, 5])
    #expect(!unsupplied.color)
    #expect(!unsupplied.sound)
    #expect(unsupplied.size == 1)

    let supplied = try Parsed.parse([
      "--round", "--cool", "--point", "6", "--points", "7", "--color",
      "--enable-sound", "--size", "2",
    ])
    #expect(supplied.shape == .round)
    #expect(supplied.tones == [.cool])
    #expect(supplied.point.x == 6)
    #expect(supplied.points.map(\.x) == [7])
    #expect(supplied.color)
    #expect(supplied.sound)
    #expect(supplied.size == 2)
  }

  @Test func argumentNameOfMultipleDefinitions() throws {
    // An `EnumerableFlag` property is named after itself, not after the flag
    // of its 1st case, and a flag that has an inversion is named without the
    // prefix of the inversion.
    #expect(
      try Parsed.parse([]).names == [
        "shape": "shape",
        "tones": "tones",
        "point": "point",
        "points": "points",
        "color": "color",
        "sound": "sound",
        "size": "size",
      ])
  }

  @Test func parsedExternalDefaultHelp() {
    // `--point` is no longer required, the secret value of `--color` is not
    // shown, and the invalid value of `--size` is not used.
    #expect(
      Parsed.helpMessage() == """
        USAGE: parsed <options>

        OPTIONS:
          --round/--square/--oblong
                                  (default: --square)
          --warm/--cool/--dim
          --point <point>
          --points <points>
          --color/--no-color
          --enable-sound/--disable-sound
                                  (default: --disable-sound)
          --size <size>           (default: 1)
          -h, --help              Show help information.

        """)
  }
}
