import Foundation

extension String {
    /// An extension that will trim the prefix iff it exists on a given string.
    ///
    /// - parameter prefix: The prefix string that you would like to trim if it exists.
    @available(macOS, deprecated: 13.0, message: "Only useful when targeting macOS versions earlier than 13")
    mutating func trimPrefix(_ prefix: String) {
        guard hasPrefix(prefix), let range = range(of: prefix) else { return }

        let substring = self[range.upperBound...]
        self = String(substring)
    }
}
