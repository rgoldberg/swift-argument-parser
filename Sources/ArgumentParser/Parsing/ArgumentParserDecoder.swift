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
/// custom `init(from:)` implementations can determine where a value came from.
///
/// Cast any `Decoder` received inside `ParsableArguments.init(from:)` to
/// this protocol to access the additional capabilities. Once
/// `container(keyedBy:)` has returned, the cast succeeds whenever the decoder
/// is one of ArgumentParser's own internal decoders, i.e., always during
/// normal ArgumentParser parsing, including inside a type that is decoded via
/// an `@OptionGroup`. (The decoder that validates a type's coding keys is not
/// one of them, but its `container(keyedBy:)` always throws.)
///
/// ```swift
/// struct MyCommand: ParsableCommand {
///     @Option var limit: Int = 4
///
///     init(from decoder: any Decoder) throws {
///         let container = try decoder.container(keyedBy: CodingKeys.self)
///         if
///             let decoder = decoder as? any ArgumentParserDecoder,
///             decoder.valueSource(forKey: CodingKeys.limit) != .commandLine,
///             let external = ExternalConfig.int(
///                 forKey: decoder.commandStack
///                     + [decoder.argumentName(forKey: CodingKeys.limit)])
///         {
///             // The command line did not supply a value, so an external
///             // source may.
///             _limit = Option(externalDefault: external)
///         } else {
///             // Decode what SAP found (command line value, or declared
///             // default).
///             _limit = try container.decode(Option<Int>.self, forKey: .limit)
///         }
///     }
/// }
/// ```
///
/// - Note: The concrete types that conform to this protocol are internal to
///   ArgumentParser. You never need to name a concrete type; always work
///   through this protocol.
public protocol ArgumentParserDecoder: Decoder {

  /// The command names from the root command to the command that is being
  /// decoded, inclusive.
  ///
  /// For a tool invoked as `cmd sub`, when decoding `sub`, this returns
  /// `["cmd", "sub"]`. When decoding `cmd`, this returns `["cmd"]`.
  var commandStack: [String] { get }

  /// Returns where the value for `key` came from.
  ///
  /// You can call this before or after decoding the value for `key`.
  ///
  /// - Parameter key: A `CodingKey` from the same `CodingKeys` enum used in the
  ///   surrounding `container(keyedBy:)` call.
  ///
  /// - Returns: The source of the value for `key`.
  func valueSource(forKey key: some CodingKey) -> ArgumentValueSource

  /// Returns the name that identifies the argument for `key` on the command
  /// line, without any dash prefix.
  ///
  /// For an option or flag, this is its preferred name: its first long name,
  /// or its first short name if it has no long name (e.g., `download-limit`
  /// for `--download-limit`). For a positional argument, which has no name,
  /// this is its value name: the `valueName` of its help, if any, otherwise
  /// the property name converted like a long name.
  ///
  /// - Parameter key: A `CodingKey` from the same `CodingKeys` enum used in the
  ///   surrounding `container(keyedBy:)` call.
  ///
  /// - Returns: The name of the argument for `key`.
  func argumentName(forKey key: some CodingKey) -> String
}

// MARK: - ArgumentValueSource

/// Where the value of a parsable property came from.
public enum ArgumentValueSource: Sendable, Hashable {
  /// The value was supplied on the command line.
  case commandLine

  /// The command line did not supply a value, so SAP uses the property's
  /// default value: its declared default value, or `nil` for an optional
  /// property.
  case defaultValue

  /// The command line did not supply a value & the property has no default
  /// value, so decoding the property throws an error.
  case missing
}

// MARK: - ExternallyDefaultable

/// A parsable property wrapper that can be created from a default value
/// obtained from outside ArgumentParser, like a configuration file.
///
/// Use this inside a custom `init(from:)` to initialize a property whose value
/// the command line did not supply.
public protocol ExternallyDefaultable {
  /// The type of the wrapped value.
  associatedtype Value

  /// Creates a property wrapper that holds the given value.
  ///
  /// - Parameter value: The value to hold.
  init(externalDefault value: Value)
}

// MARK: - ExternallyDefaulted

/// A parsable type whose properties can obtain default values from outside
/// ArgumentParser, like a configuration file.
///
/// Conform a `ParsableArguments` or `ParsableCommand` type whose custom
/// `init(from:)` uses external default values to this protocol, so that help &
/// usage output reflect them: a property that has an external default value is
/// shown as optional, with that value as its default value.
///
/// ```swift
/// extension MyCommand: ExternallyDefaulted {
///     static func externalDefault(
///         forPropertyNamed propertyName: String,
///         argumentName: String,
///         commandStack: [String]
///     ) -> ExternalDefault? {
///         guard propertyName == "limit" else { return nil }
///         return ExternalConfig.int(forKey: commandStack + [argumentName])
///             .map { ExternalDefault(valueDescription: String($0)) }
///     }
/// }
/// ```
public protocol ExternallyDefaulted {
  /// Returns the external default value of a property, if any.
  ///
  /// - Parameters:
  ///   - propertyName: The name of the property.
  ///   - argumentName: The name that identifies the argument for the property
  ///     on the command line, without any dash prefix, exactly like
  ///     `ArgumentParserDecoder.argumentName(forKey:)`.
  ///   - commandStack: The command names from the root command to the command
  ///     whose help or usage is being generated, inclusive, exactly like
  ///     `ArgumentParserDecoder.commandStack`.
  ///
  /// - Returns: The external default value of the property, or `nil` if it has
  ///   none.
  static func externalDefault(
    forPropertyNamed propertyName: String,
    argumentName: String,
    commandStack: [String]
  ) -> ExternalDefault?
}

/// An external default value of a parsable property, as help output shows it.
public struct ExternalDefault: Sendable, Hashable {
  /// The description of the value, or `nil` to show no value (e.g., because
  /// the value is secret).
  public var valueDescription: String?

  /// Creates an external default value.
  ///
  /// - Parameter valueDescription: The description of the value, or `nil` to
  ///   show no value.
  public init(valueDescription: String?) {
    self.valueDescription = valueDescription
  }
}

extension ArgumentSet {
  /// Returns this argument set with each argument that has an external default
  /// value marked as optional & showing that value as its default value.
  func applyingExternalDefaults(
    commandStack: some Sequence<ParsableCommand.Type>
  ) -> ArgumentSet {
    let commandStack = commandStack.map { $0._commandName }
    var result = self
    result.content = content.map { definition in
      guard
        let externalDefault = definition.help.externalDefault?(commandStack)
      else { return definition }
      var definition = definition
      definition.help.options.insert(.isOptional)
      definition.help.defaultValue = externalDefault.valueDescription
      return definition
    }
    return result
  }
}

extension ArgumentDefinition {
  /// The name that identifies this argument on the command line, without any
  /// dash prefix.
  var externalName: String {
    names.preferredName?.valueString ?? valueName
  }
}

extension Argument: ExternallyDefaultable {
  public init(externalDefault value: Value) {
    self.init(_parsedValue: .value(value))
  }
}

extension Flag: ExternallyDefaultable {
  public init(externalDefault value: Value) {
    self.init(_parsedValue: .value(value))
  }
}

extension Option: ExternallyDefaultable {
  public init(externalDefault value: Value) {
    self.init(_parsedValue: .value(value))
  }
}
