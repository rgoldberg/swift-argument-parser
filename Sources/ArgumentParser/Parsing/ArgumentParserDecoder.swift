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

// MARK: - ArgumentParserDecoder

/// A `Decoder` that exposes ArgumentParser-specific introspection so that
/// custom `init(from:)` implementations can determine parse provenance.
///
/// Cast any `Decoder` received inside `ParsableArguments.init(from:)` to
/// this protocol to access the additional capabilities.  The cast succeeds
/// whenever the decoder is ArgumentParser's own internal decoder — i.e.,
/// always during normal ArgumentParser parsing.
///
/// ```swift
/// struct MyCommand: ParsableCommand {
///     @Option var limit: Int = 4
///
///     init(from decoder: any Decoder) throws {
///         let container = try decoder.container(keyedBy: CodingKeys.self)
///         let apDecoder = decoder as? any ArgumentParserDecoder
///
///         // Decode what SAP found (CLI value, or declared default).
///         _limit = try container.decode(Option<Int>.self, forKey: .limit)
///
///         // If SAP used the declared default rather than a CLI value,
///         // an external config source may override it.
///         if apDecoder?.wasParsed(CodingKeys.limit) == false {
///             if let external = ExternalConfig.value(Int.self, forKey: "limit") {
///                 _limit = Option(wrappedValue: external)
///             }
///         }
///     }
/// }
/// ```
///
/// - Note: The concrete type that conforms to this protocol is internal to
///   ArgumentParser.  You never need to name the concrete type; always work
///   through this protocol.
public protocol ArgumentParserDecoder: Decoder {

  /// The command names decoded above the current command, ordered from root to
  /// immediate parent.
  ///
  /// For a tool invoked as `cmd sub`, when decoding `sub`, this returns
  /// `["cmd"]`. When decoding `sub`, this returns `[]`.
  var commandStack: [String] { get }

  /// Returns `true` when the value for `key` was supplied on the command line,
  /// and `false` when SAP fell back to the property's declared default value.
  ///
  /// Call this *after* `container.decode(_:forKey:)` succeeds (i.e., after a
  /// value has beeb resolved, whether from the command line or from the
  /// declared default). For properties that have neither of the aforementioned,
  /// `container.decode` will have thrown `noValue` before you reach this is
  /// called.
  ///
  /// - Parameter key: A `CodingKey` from the same `CodingKeys` enum used in the
  ///   surrounding `container(keyedBy:)` call.
  ///
  /// - Returns: `true` when the value for `key` was supplied on the command
  ///   line, and `false` when SAP fell back to the property's declared default
  ///   value.
  func wasParsed(_ key: some CodingKey) -> Bool
}
