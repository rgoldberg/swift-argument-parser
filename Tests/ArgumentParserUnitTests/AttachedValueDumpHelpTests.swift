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

@Suite struct AttachedValueDumpHelpTests {
  @Test func attachedValueDumpHelp() throws {
    try expectDumpHelp(type: AttachedValueCommand.self)
  }
}

extension AttachedValueDumpHelpTests {
  struct AttachedValueCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "A command with attached option values for testing dump help."
    )

    @Option(name: .shortAndLong, parsing: .attached)
    var level: String?

    @Option(parsing: .attached)
    var tags: [String] = []

    @Option(defaultAsFlag: "json", parsing: .attached)
    var format: String?

    @Option(
      name: .customShort("D", allowingJoined: true), parsing: .attached)
    var define: [String] = []

    @Option(name: .customShort("I", allowingJoined: true))
    var include: String?

    @Option
    var regular: String?

    @Flag
    var verbose = false

    @Argument
    var input: String
  }
}
