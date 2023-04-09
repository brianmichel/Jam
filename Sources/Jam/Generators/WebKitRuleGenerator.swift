import Foundation

/// A generator that takes in an array of ``Rule`` structurs and returns an array of well-formed dictionaries [compatible](https://developer.apple.com/documentation/safariservices/creating_a_content_blocker#overview) with WKWebView/WebKit's content blocking system.
public struct WebKitRuleGenerator: RuleGenerator {
    public init() {}

    /// Generate JSON Data to write to disk.
    ///
    /// - parameter rules: The input set of rules to generate data for.
    /// - returns: UTF-8 encoded JSON data.
    /// - throws: This can throw errors from serializing the JSON object to data.
    public func generateData(for rules: [Rule]) throws -> Data {
        let rules = generate(for: rules)
        let data = try JSONSerialization.data(withJSONObject: rules)
        return data
    }

    /// Generate a JSON-compatible array of dictionaries that represent the rules that can be applied.
    ///
    /// - parameter rules: An array of ``Rule``s that you would like to transform into WKWebView/WebKit
    /// compliant JSON elements.
    public func generate(for rules: [Rule]) -> [[String: Any]] {
        var cssExceptions = [String: Set<String>]()
        var cssHiding = [String: Set<String>]()

        var all: [[String: Any]] = rules.compactMap { rule in
            switch rule {
            case let .domainSpecificCSSException(domains: domains, selector: selector):
                for domain in domains {
                    var exception = cssExceptions[domain] ?? Set()
                    exception.insert(selector)
                    cssExceptions[domain] = exception
                }
                return nil
            case let .elementHiding(domains: domains, selector: selector):
                guard let domains else { return nil }

                for domain in domains {
                    let key = domain.replacingOccurrences(of: ".", with: "\\.")
                    var hiding = cssHiding[key] ?? Set()
                    hiding.insert(selector)
                    cssHiding[key] = hiding
                }
                return nil
            case let .url(
                pattern: pattern,
                options: options,
                action: action
            ):
                var filter = ".*"
                switch pattern.type {
                case .substring:
                    let newPattern = pattern.trigger
                        .replacingOccurrences(of: "|", with: "\\|")
                        .replacingOccurrences(of: "*", with: ".*")
                        .replacingOccurrences(of: ".", with: "\\.")
                        .replacingOccurrences(of: "^", with: "[/:]")
                    filter = "^[^:]+:(//)?.*\(newPattern)"
                case .wildcard:
                    let newPattern = pattern.trigger
                        .replacingOccurrences(of: "|", with: "\\|")
                        .replacingOccurrences(of: "*", with: ".*")
                        .replacingOccurrences(of: ".", with: "\\.")
                        .replacingOccurrences(of: "^", with: "[/:]")
                    filter = "^[^:]+:(//)?.*\(newPattern)"
                case .regex:
                    //filter = pattern
                    return nil
                }

                var trigger: [String: Any] = [
                    "url-filter": filter,
                ]

                trigger["resource-type"] = Array(Set(Rule.Options.ElementType.allCases.map(\.webKitResourceType)))

                if !options.elements.allowed.isEmpty {
                    let allMinusAllowed = Set(Rule.Options.ElementType.allCases)
                        .subtracting(options.elements.allowed)
                    trigger["resource-type"] = Array(Set(allMinusAllowed.map(\.webKitResourceType)))
                }

                if !options.domains.blocked.isEmpty {
                    trigger["if-domain"] = options.domains.blocked
                }

                if options.source != .any {
                    trigger["load-type"] = [options.source.webKitSourceType]
                }

                trigger["url-filter-is-case-sensitive"] = options.matchCase

                return [
                    "trigger": trigger,
                    "action": [
                        "type": action == .deny ? "block" : "ignore-previous-rules"
                    ]
                ]
            }
        }

        for (key, value) in cssHiding {
            all.append([
                "trigger": [
                    "url-filter": "^[^:]+:(//)?([^/:]*\\.)?\(key)[/:]",
                    "if-domain": [key]
                ] as [String : Any],
                "action": [
                    "type": "css-display-none",
                    "selector": value.joined(separator: ", ")
                ]
            ])
        }

        return all
    }
}

extension Rule.Options.ElementType {
    /// A mapping of a given element type to the type that is supported in WKWebView (and WebKit?)
    ///
    /// - returns: A string that represents the resource which is within the [allowed list](https://developer.apple.com/documentation/safariservices/creating_a_content_blocker#3030753) of types.
    var webKitResourceType: String {
        switch self {
        case .script:
            return "script"
        case .image:
            return "image"
        case .stylesheet:
            return "style-sheet"
        case .object:
            return "other"
        case .xmlhttprequest:
            return "fetch"
        case .subdocument:
            return "other"
        case .other:
            return "other"
        case .ping:
            return "ping"
        case .media:
            return "media"
        case .websocket:
            return "websocket"
        case .font:
            return "font"
        case .popup:
           return "popup"
        case .webtransport:
            return "other"
        case .webbundle:
            return "other"
        }
    }
}

extension Rule.Options.SourceType {
    var webKitSourceType: String {
        switch self {
        case .any:
            return "any"
        case .first:
            return "first-party"
        case .third:
            return "third-party"
        }
    }
}
