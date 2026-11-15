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

@Suite struct AttachedValueEndToEndTests {}

// MARK: Attached

private struct Attached: ParsableArguments {
  @Option(name: .shortAndLong, parsing: .attached)
  var name: String?

  @Option(parsing: .attached)
  var level: Int?

  @Option(name: .customShort("D", allowingJoined: true), parsing: .attached)
  var define: [String] = []

  @Option(defaultAsFlag: "json", parsing: .attached)
  var format: String?

  @Argument var rest: [String] = []
}

extension AttachedValueEndToEndTests {
  @Test func attached_delimited() throws {
    expectParse(Attached.self, ["--name=a", "b"]) { options in
      #expect(options.name == "a")
      #expect(options.rest == ["b"])
    }
    expectParse(Attached.self, ["-n=a", "--level=1"]) { options in
      #expect(options.name == "a")
      #expect(options.level == 1)
    }
    expectParse(Attached.self, ["--level=2", "--name="]) { options in
      #expect(options.name == "")
      #expect(options.level == 2)
    }
  }

  @Test func attached_joined() throws {
    expectParse(Attached.self, ["-Da", "b"]) { options in
      #expect(options.define == ["a"])
      #expect(options.rest == ["b"])
    }
    expectErrorMessage(
      Attached.self, ["-na"],
      """
      Unknown option '-na'. Did you mean '--name'?
         or: Missing value for '-n=<name>' in '-na'
      """)
  }

  @Test func attached_array() throws {
    expectParse(Attached.self, ["-D=a", "b", "-Dc", "-D=d"]) { options in
      #expect(options.define == ["a", "c", "d"])
      #expect(options.rest == ["b"])
    }
  }

  @Test func attached_forbidsSeparated() throws {
    expectErrorMessage(
      Attached.self, ["--name", "a"], "Missing value for '--name=<name>'")
    expectErrorMessage(
      Attached.self, ["-n", "a"], "Missing value for '-n=<name>'")
    expectErrorMessage(
      Attached.self, ["--level", "1"], "Missing value for '--level=<level>'")
    expectErrorMessage(
      Attached.self, ["-D", "a"], "Missing value for '-D=<D>'")
  }

  @Test func attached_invalidValue() throws {
    expectErrorMessage(
      Attached.self, ["--level=a"],
      "The value 'a' is invalid for '--level=<level>'")
  }

  @Test func attached_otherDelimiter() throws {
    expectErrorMessage(
      Attached.self, ["--name:a"],
      "Unknown option '--name:a'. Did you mean '--name'?")
  }

  @Test func attached_defaultAsFlag() throws {
    expectParse(Attached.self, ["--format", "a"]) { options in
      #expect(options.format == "json")
      #expect(options.rest == ["a"])
    }
    expectParse(Attached.self, ["--format=yaml", "a"]) { options in
      #expect(options.format == "yaml")
      #expect(options.rest == ["a"])
    }
    expectParse(Attached.self, ["--format=", "a"]) { options in
      #expect(options.format == "")
      #expect(options.rest == ["a"])
    }
    expectParse(Attached.self, ["a"]) { options in
      #expect(options.format == nil)
    }
  }
}

// MARK: Subcommands

private struct Parent: ParsableCommand {
  static let configuration = CommandConfiguration(subcommands: [Child.self])

  @Option(parsing: .attached)
  var mode: String?

  struct Child: ParsableCommand {
    @OptionGroup var parent: Parent

    @Option(parsing: .attached)
    var host: [String] = []
  }
}

extension AttachedValueEndToEndTests {
  @Test func attached_subcommand() throws {
    expectParseCommand(
      Parent.self, Parent.Child.self,
      ["child", "--mode=a", "--host=b", "--host=c"]
    ) { child in
      #expect(child.parent.mode == "a")
      #expect(child.host == ["b", "c"])
    }
  }
}
