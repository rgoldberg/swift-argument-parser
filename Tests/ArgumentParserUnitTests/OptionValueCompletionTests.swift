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

extension SerializedTests {
  @Suite struct OptionValueCompletionTests {}
}

extension SerializedTests.OptionValueCompletionTests {
  @Test func optionValueCompletion_Bash() throws {
    let script = try CompletionsGenerator(
      command: OptionValueCommand.self, shell: .bash
    )
    .generateCompletionScript()
    try expectSnapshot(actual: script, extension: "bash")
  }

  @Test func optionValueCompletion_Zsh() throws {
    let script = try CompletionsGenerator(
      command: OptionValueCommand.self, shell: .zsh
    )
    .generateCompletionScript()
    try expectSnapshot(actual: script, extension: "zsh")
  }

  @Test func optionValueCompletion_Fish() throws {
    let script = try CompletionsGenerator(
      command: OptionValueCommand.self, shell: .fish
    )
    .generateCompletionScript()
    try expectSnapshot(actual: script, extension: "fish")
  }

  struct OptionValueCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "optionvalue-test",
      abstract: "A command with option values for testing completion scripts."
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

    @Option(
      name: .customLong("mode", withSingleDash: true),
      completion: .list(["fast", "slow"]))
    var mode: String?

    @Flag
    var verbose = false

    @Argument(completion: .file())
    var input: String
  }
}
