import Foundation

/// Can represent any rule generate which produces data.
public protocol RuleGenerator {
    /// Generate data for a set of rules that could be written to disk.
    ///
    /// - parameter rules: The input set of rules to generate data for.
    /// - returns: Data to write a file representation of the input rules, should be UTF-8 encoded.
    /// - throws: Errors thrown from the serialization process should be handled by the caller.
    func generateData(for rules: [Rule]) throws -> Data
}
