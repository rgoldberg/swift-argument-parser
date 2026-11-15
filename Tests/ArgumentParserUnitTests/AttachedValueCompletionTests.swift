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
  @Suite struct AttachedValueCompletionTests {}
}

extension SerializedTests.AttachedValueCompletionTests {
  @Test func attachedValueCompletion_Bash() throws {
    let script = try CompletionsGenerator(
      command: AttachedValueCommand.self, shell: .bash
    )
    .generateCompletionScript()
    try expectSnapshot(actual: script, extension: "bash")
  }

  @Test func attachedValueCompletion_Zsh() throws {
    let script = try CompletionsGenerator(
      command: AttachedValueCommand.self, shell: .zsh
    )
    .generateCompletionScript()
    try expectSnapshot(actual: script, extension: "zsh")
  }

  @Test func attachedValueCompletion_Fish() throws {
    let script = try CompletionsGenerator(
      command: AttachedValueCommand.self, shell: .fish
    )
    .generateCompletionScript()
    try expectSnapshot(actual: script, extension: "fish")
  }

  struct AttachedValueCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "attachedvalue-test",
      abstract:
        "A command with attached option values for testing completion scripts."
    )

    @Option(
      name: .shortAndLong, parsing: .attached,
      completion: .list(["DEBUG", "INFO"]))
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

    @Argument(completion: .file())
    var input: String
  }
}
