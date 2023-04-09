import Foundation
import OSLog

private let logger = Logger(subsystem: "me.foureyes.Jam", category: "RuleParser")

/// The parser that can turn text into well formed content blocking rules.
/// A more formal definition for rules can be found [here](https://help.adblockplus.org/hc/en-us/articles/360062733293-How-to-write-filters#elemhide_basic).
public struct RuleParser {
    public init() {}

    /// Parse a line of text into a rule potentially.
    ///
    /// - parameter rule: A line from an EasyList file that has not been modified.
    /// - returns: Optionally a ``Rule`` if the text can be parsed successfully.
    public func parse(rule: String) -> Rule? {
        // We don't parse comments or empty rules, so let's bail early.
        guard !rule.isEmpty
                && !rule.isComment
        else {
            logger.debug("Skipping: \(rule)")
            return nil
        }

        if rule.isDomainSpecificCSSException {
            // Domain specific exception for element hiding.
            return parseDomainSpecificCSSException(rule: rule)
        }
        else if rule.isABPRule {
            // This is Adblock Pro specific, ignore
            return nil
        }
        else if rule.isElementHidingRule {
            // This is just an element hiding rule, these are optionally domain specific.
            return parseElementHidingRule(rule: rule)
        }
        else {
            // This is a regular URL rule
            return parseURLRule(rule: rule)
        }
    }

    /// Asynchronously parse a file into a set of ``Rule``s
    /// - parameter file: A valid file URL.
    /// - returns: An array of parsed ``Rule``s (this can be empty if no parsable rules are present in the file).
    public func parse(file: String) async -> [Rule] {
        guard let reader = StreamReader(path: file) else { return [] }

        defer {
            reader.close()
        }

        var rules = [Rule]()

        for line in reader {
            guard let rule = parse(rule: line) else { continue }
            rules.append(rule)
        }

        return rules
    }

    // MARK: - Rule-specific Parsing Functions

    private func parseDomainSpecificCSSException(rule: String) -> Rule? {
        let components = rule.components(separatedBy: "#@#")
        guard components.count == 2 else { return nil }

        let domainsRaw = components[0]
        let domains = domainsRaw.components(separatedBy: ",")
        guard domains.count >= 1 else { return nil }
        let selector = components[1]

        logger.debug("[CSS Exception] Domain: \(domains), Selector: \(selector)")

        return .domainSpecificCSSException(domains: domains, selector: selector)
    }

    private func parseElementHidingRule(rule: String) -> Rule? {
        if rule.starts(with: "##") {
            // This is a rule like '## .ad-wide' and it contains no domain.
            let trimmed = String(rule.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines))
            guard !trimmed.isEmpty else { return nil }

            logger.debug("[Element Hiding] Domains: nil, Selector: \(trimmed)")
            return .elementHiding(domains: nil, selector: trimmed)
        }
        else {
            // This is a rule like 'miloserdov.org,reneweconomy.com.au,wpneon.com###custom_html-10'
            // it contains a set of domains and a selector.
            let components = rule.components(separatedBy: "##")
            guard components.count == 2 else { return nil }

            let domainsRaw = components[0]
            let domains = domainsRaw.components(separatedBy: ",")
            guard domains.count >= 1 else { return nil }

            logger.debug("[Element Hiding] Domains: \(domains), Selector: \(components[1])")
            return .elementHiding(domains: domains, selector: components[1])
        }
    }

    private func parseURLRule(rule: String) -> Rule? {
        var pattern: String? = nil
        var options: String? = nil

        // If a URL rule has a `$` in it, that means that it can contain two different sides to it
        // the structure can kind of look like this `pattern$options`, so we split these
        // and bind them into our variables. Otherwise, we assume it's all pattern.
        if rule.contains("$") {
            // -adap.$domain=~l-adap.org
            // $popup,third-party,domain=thign.tv|lol.com|hmm.com
            guard let positionOfDollarSign = rule.firstIndex(of: "$") else {
                // For some reason there is no first index of the `$` character, bail.
                return nil
            }
            // See if this is a URL rule that does not contain a domain.
            if rule.distance(from: rule.startIndex, to: positionOfDollarSign) == 0 {
                pattern = ".*"
                options = String(rule.dropFirst())
            } else {
                let components = rule.components(separatedBy: "$")
                guard components.count == 2 else { return nil }

                pattern = components[0]
                options = components[1]
            }
        }
        else {
            // The rule is the pattern, there are no options.
            pattern = rule
        }

        guard let p = pattern else { return nil }

        // Determine whether this rule is an exception or not.
        var blocking = true
        if p.hasPrefix("@@") {
            blocking = false
            pattern = String(p.dropFirst(2))
        }

        // We rebind here just in case the previous steps to ensure we don't have an empty pattern.
        guard let p = pattern, !p.isEmpty else { return nil }

        var leftAnchor = Rule.Pattern.AnchorType.none
        if p.hasPrefix("||") {
            leftAnchor = .subdomain
            pattern = String(p.dropFirst(2))
        }
        else if p.hasPrefix("|") {
            leftAnchor = .boundary
            pattern = String(p.dropFirst())
        }

        var rightAnchor = Rule.Pattern.AnchorType.none
        if p.hasSuffix("|") {
            rightAnchor = .boundary
            pattern = String(p.dropLast())
        }

        // We rebind here just in case the previous steps to ensure we don't have an empty pattern.
        guard let p = pattern, !p.isEmpty else { return  nil }
        var patternType = Rule.Pattern.PatternType.substring
        // Figure out what kind of pattern we have here, this will effect how rules in the various
        // output formats get generated. This is to help the generator figure out how to build
        // the trigger strings in the output formats.
        if p.hasPrefix("/") && p.hasSuffix("/") {
            patternType = .regex
            pattern = String(p.dropFirst().dropLast())
        } else if (p.contains("*") || p.contains("^")) {
            patternType = .wildcard
        }

        var sourceType: Rule.Options.SourceType = .any
        var elementTypesToAllow = [Rule.Options.ElementType]()
        var elementTypesToBlock = [Rule.Options.ElementType]()
        var matchCase = false
        var domainsAllow = [String]()
        var domainsBlocked = [String]()

        // If there are options, parse them.
        if let o = options, !o.isEmpty {
            let split = o.components(separatedBy: ",")

            for option in split {
                var mutableOption = option
                let negated = mutableOption.hasPrefix("~")
                if negated {
                    mutableOption = String(mutableOption.dropFirst())
                }

                // While all of these are 'options' in EasyList parlance, a few options like:
                // - third-party
                // - domain
                // are actually not triggering elements, but map to different trigger parameters.
                if let type = Rule.Options.ElementType(rawValue: mutableOption) {
                    // type is known, add options
                    if negated {
                        elementTypesToAllow.append(type)
                    } else {
                        elementTypesToBlock.append(type)
                    }
                } else if mutableOption == "third-party" {
                    sourceType = negated ? .first : .third
                } else if mutableOption == "match-case" {
                    matchCase = true
                } else if mutableOption.hasPrefix("domain=") {
                    // Domain list format is 'domain=url1|url2|url3' so we need
                    // to split it out to find all of the domains and whether or not
                    // the are negated or not.
                    let rawDomains = mutableOption.dropFirst(7)
                    rawDomains.components(separatedBy: "|").forEach { domain in
                        let domainAllowed = domain.hasPrefix("~")
                        if domainAllowed {
                            domainsAllow.append(String(domain.dropFirst()))
                        } else {
                            domainsBlocked.append(domain)
                        }
                    }
                }
            }
        }

        let ruleOptions = Rule.Options(
            source: sourceType,
            elements: .init(
                allowed: elementTypesToAllow,
                blocked: elementTypesToBlock
            ),
            domains: .init(
                allowed: domainsAllow,
                blocked: domainsBlocked
            ),
            matchCase: matchCase
        )
        let finalPattern = Rule.Pattern(
            trigger: p,
            leftAnchor: leftAnchor,
            rightAnchor: rightAnchor,
            type: patternType
        )

        logger.debug("[URL Blocking] Pattern: \(p), Will Block: \(blocking), Allow Elements: \(elementTypesToAllow), Blocked Elements: \(elementTypesToBlock)")
        return .url(
            pattern: finalPattern,
            options: ruleOptions,
            action: blocking ? .deny : .allow
        )
    }
}

extension String {
    /// Determines whether the text is a Domain-specific CSS Exception rule.
    var isDomainSpecificCSSException: Bool {
        return contains("#@#")
    }

    /// Determines whether or not the text is an Adblock Pro specific rule.
    var isABPRule: Bool {
        return contains("#?#")
    }

    /// Determines whether or not the text is generic element hiding rule.
    var isElementHidingRule: Bool {
        return contains("##")
    }

    ///Determines whether or not the text is a comment.
    var isComment: Bool {
        return hasPrefix("!") || hasPrefix("[Adblock")
    }
}
