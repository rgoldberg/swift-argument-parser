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
  /// for `--download-limit`). A flag that has an inversion is identified by
  /// its preferred name without the prefix of the inversion (e.g., `index`
  /// for `--enable-index` & `--disable-index`), and an `EnumerableFlag`
  /// property, each of whose cases has its own names, by the property name
  /// converted like a long name. For a positional argument, which has no
  /// name, this is its value name: the `valueName` of its help, if any,
  /// otherwise the property name converted like a long name.
  ///
  /// - Parameter key: A `CodingKey` from the same `CodingKeys` enum used in the
  ///   surrounding `container(keyedBy:)` call.
  ///
  /// - Returns: The name of the argument for `key`.
  func argumentName(forKey key: some CodingKey) -> String

  /// Returns the value that the property for `key` would have if the command
  /// line supplied only `arguments` for it.
  ///
  /// Use this to obtain a value that only ArgumentParser can create from an
  /// external default (e.g., via the `transform` closure of an option), then
  /// pass it to `ExternallyDefaultable.init(externalDefault:)`.
  ///
  /// - Parameters:
  ///   - key: A `CodingKey` from the same `CodingKeys` enum used in the
  ///     surrounding `container(keyedBy:)` call.
  ///   - arguments: For an option or a positional argument, its values; for a
  ///     flag, the names of its flags, without any dash prefix (e.g.,
  ///     `no-color` for `--no-color`).
  ///
  /// - Returns: The value, or `nil` if the property would have none.
  ///
  /// - Throws: An error if any of `arguments` is invalid for the property.
  func value(
    forKey key: some CodingKey, parsing arguments: [String]
  ) throws -> Any?
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
///             .map { ExternalDefault(value: $0) }
///     }
/// }
/// ```
public protocol ExternallyDefaulted {
  /// Returns the external default value of a property, if any.
  ///
  /// This is called only for a property that the conforming type itself
  /// declares, never for a property of a type that it includes via an
  /// `@OptionGroup`.
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

/// An external default value of a parsable property.
public struct ExternalDefault {
  fileprivate enum Source {
    case arguments([String], isValueShown: Bool)
    case value(Any?)
  }

  fileprivate var source: Source

  /// Creates an external default value.
  ///
  /// - Parameter value: The value, which help output describes like a
  ///   declared default value of the property, or `nil` to show no value
  ///   (e.g., because the value is secret).
  public init(value: Any?) {
    source = .value(value)
  }

  /// Creates an external default value that ArgumentParser parses from
  /// `arguments`, exactly like
  /// `ArgumentParserDecoder.value(forKey:parsing:)`.
  ///
  /// The property has no external default value if any of `arguments` is
  /// invalid for it.
  ///
  /// - Parameters:
  ///   - arguments: For an option or a positional argument, its values; for a
  ///     flag, the names of its flags, without any dash prefix (e.g.,
  ///     `no-color` for `--no-color`).
  ///   - isValueShown: Whether help output describes the value like a declared
  ///     default value of the property; pass `false` to show no value (e.g.,
  ///     because the value is secret).
  public init(arguments: [String], isValueShown: Bool = true) {
    source = .arguments(arguments, isValueShown: isValueShown)
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
      let shownValue: Any?
      switch externalDefault.source {
      case .arguments(let arguments, let isValueShown):
        guard
          let key = definition.help.keys.first,
          let value = try? value(forKey: key, parsing: arguments)
        else { return definition }
        shownValue = isValueShown ? value : nil
      case .value(let value):
        shownValue = value
      }
      var definition = definition
      definition.help.options.insert(.isOptional)
      definition.help.defaultValue = shownValue.flatMap { value in
        if let describe = definition.help.externalDefaultDescription {
          return describe(value)
        }
        if case .nullary = definition.update { return nil }
        return ArgumentSet.defaultValueDescription(value)
      }
      return definition
    }
    return result
  }

  /// Returns the value that the property for `key` would have if the command
  /// line supplied only `arguments` for it: the values of an option or of a
  /// positional argument, or the names of flags, without any dash prefix.
  func value(forKey key: InputKey, parsing arguments: [String]) throws -> Any? {
    let definitions = content.filter { $0.help.keys.contains(key) }
    var values = ParsedValues(originalInput: [])
    for definition in definitions {
      try definition.initial(InputOrigin(), &values)
    }
    for argument in arguments {
      let origin = InputOrigin(element: .defaultValue)
      let invalid = ParserError.unableToParseValue(
        origin, nil, argument, forKey: key, originalError: nil)
      switch definitions.first?.update {
      case .unary(let update), .optionalUnary(_, let update):
        try update(origin, nil, argument, &values)
      case .nullary:
        guard
          let definition = definitions.first(where: {
            $0.names.contains { $0.valueString == argument }
          }),
          case .nullary(let update) = definition.update
        else { throw invalid }
        try update(origin, nil, &values)
      case nil:
        throw invalid
      }
    }
    return values.element(forKey: key)?.value
  }

  /// Returns the description of a default value whose type is known only
  /// dynamically, like that of a declared default value.
  private static func defaultValueDescription(_ value: Any) -> String? {
    if let values = value as? [Any] {
      return values.isEmpty
        ? nil
        : values.compactMap(defaultValueDescription).joined(separator: ", ")
    }
    if let value = value as? (any CaseIterable & RawRepresentable) {
      return String(describing: value.rawValue)
    }
    return (value as? any ExpressibleByArgument)?.defaultValueDescription
  }
}

extension ArgumentDefinition {
  /// The name that identifies this argument on the command line, without any
  /// dash prefix.
  ///
  /// A flag that has an inversion is identified by its name without the prefix
  /// of the inversion, and the argument of an `EnumerableFlag`, each of whose
  /// cases has its own names, by the property name converted like a long name.
  var externalName: String {
    help.externalName ?? names.preferredName?.valueString ?? valueName
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
