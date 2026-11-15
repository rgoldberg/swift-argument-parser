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

extension HelpGenerationTests {
  struct AttachedValues: ParsableArguments {
    @Option(name: .shortAndLong, parsing: .attached, help: "Attached.")
    var attached: String

    @Option(parsing: .attached, help: "Attached array.")
    var array: [String] = []

    @Option(
      defaultAsFlag: "json", parsing: .attached,
      help: "Attached default as flag.")
    var format: String?

    @Option(help: "Separated or attached.")
    var either: String?
  }

  @Test func attachedValueHelpOutput() async throws {
    try requireHelp(
      .default, for: AttachedValues.self,
      equals: """
        USAGE: attached_values --attached=<attached> [--array=<array> ...] [--format[=<format>]] [--either <either>]

        OPTIONS:
          -a, --attached=<attached>
                                  Attached.
          --array=<array>         Attached array.
          --format[=<format>]     Attached default as flag. (default as flag: json)
          --either <either>       Separated or attached.
          -h, --help              Show help information.

        """)
  }

  @Test func attachedValueErrorHelp() async throws {
    expectFullErrorMessage(
      AttachedValues.self, ["--attached"],
      """
      Error: Missing value for '--attached=<attached>'
      Help:  --attached=<attached>  Attached.
      Usage: attached_values --attached=<attached> [--array=<array> ...] [--format[=<format>]] [--either <either>]
        See 'attached_values --help' for more information.
      """)
  }
}
