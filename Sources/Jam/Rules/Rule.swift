import Foundation

/// The basic unit of content blocking.
///
/// There are specific rule types that are supported.
/// So far the following rule types are supported:
/// - CSS exception rules
/// - Generic element hiding rules
/// - URL matching rules
public enum Rule {
    /// The action that should be taken when the rule is triggered.
    public enum Action {
        /// Allow the resource to load successfully.
        case allow
        /// Do not allow the resource to load successfully.
        case deny
    }

    /// The rule trigger pattern which specifies how the trigger phrase should
    /// be treated by down-stream rule generators.
    public struct Pattern {
        /// Represents the associated anchor needed for the pattern based on the originally
        /// parsed rule from the EasyList.
        public enum AnchorType {
            /// No anchor required.
            case none
            /// Use an anchor that represents subdomain specificity.
            case subdomain
            /// Use an anchor that represents boundary specificity.
            case boundary
        }

        /// How the trigger should be interpreted when generating rules.
        public enum PatternType {
            /// The trigger is a regex and should be treated as such.
            case regex
            /// The trigger is a wildcard pattern and will match many cases.
            case wildcard
            /// The trigger is a substring pattern to match specific cases.
            case substring
        }

        /// The actual string that can be used for triggering a rule.
        var trigger: String
        /// An anchor type that can help describe part of how a trigger should be treated.
        var leftAnchor: AnchorType
        /// An anchor type that can help describe part of how a trigger should be treated.
        var rightAnchor: AnchorType
        /// The ``PatternType`` of this specific pattern.
        var type: PatternType
    }

    /// Options that can be associated with a specific rule.
    public struct Options {
        /// Helps limit the rule triggering depending on if a loaded
        /// was from a first or third party location.
        public enum SourceType: String {
            /// Allow a rule to trigger when loaded from any source.
            case any
            /// Allow a rule to trigger only if the resource is
            /// being loaded from a first party source.
            case first
            /// Allow a rule to trigger only if the resource is
            /// being loaded form a third party source.
            case third
        }

        /// Element types that can trigger a rule.
        public enum ElementType: String, CaseIterable {
            /// All other elements that might be unspecified.
            case other
            /// All scripts.
            case script
            /// All images.
            case image
            /// All stylesheets.
            case stylesheet
            /// All objects.
            case object
            /// All requests that are using the xmlhttprequest type.
            case xmlhttprequest
            /// All subdocuments of the main document.
            case subdocument
            /// Pings?
            case ping
            /// All media (images, audio, video, etc.).
            case media
            /// All fonts.
            case font
            /// All popups.
            case popup
            /// All websocket connections.
            case websocket
            /// Webtransport?
            case webtransport
            /// Web bundles?
            case webbundle
        }

        /// The domains that should be considered for the rule.
        public struct Domains {
            /// These domains will **not** trigger the rule.
            var allowed: [String]
            /// These domains will trigger the rule
            var blocked: [String]
        }

        /// The list of elements that should be considered for the rule.
        public struct Elements {
            /// These elements will **not** trigger the rule.
            var allowed: [ElementType]
            /// These elements will trigger the rule.
            var blocked: [ElementType]
        }

        /// The type of source that can trigger the rule.
        var source: SourceType
        /// The list of elements that can trigger the rule.
        var elements: Elements
        /// The allow and blocked domains for the rule.
        var domains: Domains
        /// Whether or not the rule is case sensitive.
        var matchCase: Bool
    }

    /// A CSS exception for a specific domain, meaning, this will unhide something more than likely.
    /// - parameter domains: A set of domains that the exception should be applied for.
    /// - parameter selector: The CSS selector that should be used to select elements.
    case domainSpecificCSSException(domains: [String], selector: String)
    /// Hides elements that match a CSS selector for an optional set of domains.
    /// - parameter domains: An optional set of domains that the selector should be applied to, if this is nil that means it will be specified for all domains.
    /// - parameter selector: The CSS selector that should be used to select elements.
    case elementHiding(domains: [String]?, selector: String)
    /// Matches a specific URL pattern and set of options to apply an action.
    /// - parameter pattern: The URL pattern that should be matched to trigger the action.
    /// - parameter options: The options for the pattern which could change what or how the action is triggered.
    /// - parameter matchCase: Whether or not the case should be matched in the pattern.
    /// - parameter domains: An list of domains that should be opted into a rule, if blank, all domains will get opted in.
    /// - parameter action: Specifies whether the rule is going to allow or deny loading of a resource.
    case url(
        pattern: Pattern,
        options: Options,
        action: Action
    )
}
