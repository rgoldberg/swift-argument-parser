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

import ArgumentParserTestHelpers
import Testing

@testable import ArgumentParser

@Suite struct OptionValueDumpHelpTests {
  @Test func optionValueDumpHelp() throws {
    try expectDumpHelp(type: OptionValueCommand.self)
  }
}

extension OptionValueDumpHelpTests {
  struct OptionValueCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "A command with option values for testing dump help."
    )

    @Option(completion: .list(["DEBUG", "INFO"]))
    var level: String?

    @Option(name: .shortAndLong, completion: .list(["red", "green"]))
    var tags: [String] = []

    @Option(
      name: .customShort("D", allowingJoined: true),
      completion: .list(["debug", "release"]))
    var define: String?

    @Option(defaultAsFlag: "json", completion: .list(["json", "yaml"]))
    var format: String?

    @Flag
    var verbose = false

    @Argument(completion: .file())
    var input: String
  }
}
