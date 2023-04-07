import Foundation

/// A generator that takes in an array of ``Rule`` structurs and returns an array of well-formed dictionaries [compatible](https://developer.apple.com/documentation/safariservices/creating_a_content_blocker#overview) with WKWebView/WebKit's content blocking system.
public struct WebKitRuleGenerator {
    public init() {}

    /// Generate a JSON-compatible array of dictionries that represent the rules that can be applied.
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
                    var hiding = cssHiding[domain] ?? Set()
                    hiding.insert(selector)
                    cssHiding[domain] = hiding
                }
                return nil
            case let .url(
                pattern: pattern,
                options: options,
                matchCase: _,
                domains: _,
                action: _
            ):
                var filter = ".*"
                switch pattern.type {
                case .substring:
                    let newPattern = pattern.trigger
                        .replacingOccurrences(of: "|", with: "\\|")
                        .replacingOccurrences(of: "*", with: ".*")
                        .replacingOccurrences(of: "^", with: "")
                    filter = "^https?://.*\(newPattern)"
                case .wildcard:
                    let newPattern = pattern.trigger
                        .replacingOccurrences(of: "|", with: "\\|")
                        .replacingOccurrences(of: "*", with: ".*")
                        .replacingOccurrences(of: "^", with: "")
                    filter = "^https?://.*\(newPattern).*"
                case .regex:
                    //filter = pattern
                    break
                }

                var trigger: [String: Any] = [
                    "url-filter": filter,
                ]

                if !options.elements.isEmpty {
                    trigger["resource-type"] = options.elements.map(\.webKitResourceType)
                }

                return [
                    "trigger": trigger,
                    "action": [
                        "type": "block"
                    ]
                ]
            }
        }

        for (key, value) in cssHiding {
            all.append([
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": [key]
                ],
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
