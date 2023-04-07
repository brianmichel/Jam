import Foundation


public enum Rule {
    public enum Action {
        case allow
        case deny
    }

    public struct Pattern {
        public enum AnchorType {
            case none
            case subdomain
            case boundary
        }

        public enum PatternType {
            case regex
            case wildcard
            case substring
        }

        var trigger: String
        var leftAnchor: AnchorType
        var rightAnchor: AnchorType
        var type: PatternType
    }

    public struct Options {
        public enum SourceType: String {
            case any
            case first
            case third
        }

        public enum ElementType: String {
            case other
            case script
            case image
            case stylesheet
            case object
            case xmlhttprequest
            case subdocument
            case ping
            case media
            case font
            case popup
            case websocket
            case webtransport
            case webbundle
        }

        var source: SourceType
        var elements: [ElementType]
    }

    /// A rule describing a domain specific css exception.
    case domainSpecificCSSException(domains: [String], selector: String)
    /// An element hiding rule
    case elementHiding(domains: [String]?, selector: String)
    case url(
        pattern: Pattern,
        options: Options,
        matchCase: Bool,
        domains: [String],
        action: Action
    )
}
