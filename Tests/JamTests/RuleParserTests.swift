import XCTest
@testable import Jam

final class RuleParserTests: XCTestCase {
    let sut: RuleParser = RuleParser()

    func testParsingCommentRulesWithBang_ReturnsNil() {
        let rule = sut.parse(rule: "! Invideo advert: gizmodo.com,avclub.com,qz.com,lifehacker.com,theroot.com")

        XCTAssertNil(rule, "Comment lines should be ignored by the parser.")
    }

    func testParsingNonCommentRules_ReturnsSomething() throws {
        let rule = try XCTUnwrap(sut.parse(rule: ".com/ad/$~image,third-party,domain=~mediaplex.com|~warpwire.com"))

        if case let Rule.url(pattern, options, matchCase, domains, action) = rule {
            XCTAssertEqual(pattern.trigger, ".com/ad/")
            XCTAssertEqual(options.source, .third)
            XCTAssertEqual(domains.count, 2)
            XCTAssertEqual(options.elements.count, 1)
            XCTAssertEqual(pattern.type, .substring)
            XCTAssertEqual(pattern.leftAnchor, .none)
            XCTAssertEqual(pattern.rightAnchor, .none)
            XCTAssertEqual(matchCase, true)
            XCTAssertEqual(action, .deny)
        }
    }


    func testParsingNonCommentRules_ReturnsJustRegexWithNoOptions() throws {
        let rule = try XCTUnwrap(sut.parse(rule: ".com/ad/"))

        if case let Rule.url(pattern, options, matchCase, domains, action) = rule {
            XCTAssertEqual(pattern.trigger, ".com/ad/")
            XCTAssertEqual(options.source, .any)
            XCTAssertEqual(domains.count, 0)
            XCTAssertEqual(options.elements.count, 0)
            XCTAssertEqual(pattern.type, .substring)
            XCTAssertEqual(pattern.leftAnchor, .none)
            XCTAssertEqual(pattern.rightAnchor, .none)
            XCTAssertEqual(matchCase, true)
            XCTAssertEqual(action, .deny)
        }
    }

    func testHTMLRulesShouldBeSkipped() throws {
        let rule = try XCTUnwrap(sut.parse(rule: "### cmg-video-player-placeholder"))

        if case let Rule.elementHiding(domains: domains, selector: selector) = rule {
            XCTAssertNil(domains)
            XCTAssertEqual(selector, "cmg-video-player-placeholder")
        }
    }

    func testExceptionRulesShouldBeSkipped() throws {
        let rule = try XCTUnwrap(sut.parse(rule: "@@||www.google.*/search?q=*&oq=*&aqs=chrome.*&sourceid=chrome&$popup,third-party"))

        if case let Rule.url(pattern, options, matchCase, domains, action) = rule {
            XCTAssertEqual(pattern.trigger, "www.google.*/search?q=*&oq=*&aqs=chrome.*&sourceid=chrome&")
            XCTAssertEqual(options.source, .third)
            XCTAssertEqual(domains.count, 0)
            XCTAssertEqual(options.elements.count, 1)
            XCTAssertEqual(pattern.type, .wildcard)
            XCTAssertEqual(pattern.leftAnchor, .subdomain)
            XCTAssertEqual(pattern.rightAnchor, .none)
            XCTAssertEqual(matchCase, true)
            XCTAssertEqual(action, .allow)
        }
    }

    func testParsingFromAFile_WorksSuccessfully() async throws {
        let path = try XCTUnwrap(Bundle.module.path(forResource: "easy-list", ofType: "txt"))
        let rules = await sut.parse(file: path)

        XCTAssertNotNil(rules, "Rules parsed from a file containing rules should not be nil.")
        XCTAssertEqual(rules.count, 57188)
    }

    func testParsingUnbalancedRules_WorksSuccessfully() throws {
        let rule = try XCTUnwrap(sut.parse(rule: "$popup,third-party,domain=thign.tv|lol.com|hmm.com"))

        if case let Rule.url(pattern, options, matchCase, domains, action) = rule {
            XCTAssertEqual(pattern.trigger, "")
            XCTAssertEqual(options.source, .third)
            XCTAssertEqual(domains.count, 3)
            XCTAssertEqual(options.elements.count, 1)
            XCTAssertEqual(pattern.type, .substring)
            XCTAssertEqual(pattern.leftAnchor, .none)
            XCTAssertEqual(pattern.rightAnchor, .none)
            XCTAssertEqual(matchCase, true)
            XCTAssertEqual(action, .deny)
        }
    }

    // MARK: - Domain Specific CSS Exception Rules

    func testParsingDomainSpecificCSSExceptionRules_SingleDomain_WorksSuccessfully() throws {
        let rule = try XCTUnwrap(sut.parse(rule: "wegotads.co.za#@#.ad-source"))

        if case let Rule.domainSpecificCSSException(domains, selector) = rule {
            XCTAssertEqual(domains.count, 1)
            XCTAssertEqual(selector, ".ad-source")
        }
    }

    func testParsingDomainSpecificCSSExceptionRules_MultipleDomains_WorksSuccessfully() throws {
        let rule = try XCTUnwrap(sut.parse(rule: "isewanferry.co.jp,jreu-h.jp,junkmail.co.za,nexco-hoken.co.jp,version2.dk#@#.ad-text"))

        if case let Rule.domainSpecificCSSException(domains, selector) = rule {
            XCTAssertEqual(domains.count, 5)
            XCTAssertEqual(selector, ".ad-text")
        }
    }

    // MARK: - Element Hiding Rules

    func testParsingElementHidingRules_SingleDomain_WorksSuccessfully() throws {
        let rule = try XCTUnwrap(sut.parse(rule: "wpneon.com###custom_html-10"))

        if case let Rule.elementHiding(domains, selector) = rule {
            XCTAssertNotNil(domains)
            let unwrapped = try XCTUnwrap(domains)
            XCTAssertEqual(unwrapped.count, 1)
            XCTAssertEqual(selector, "#custom_html-10")
        }
    }

    func testParsingElementHidingRules_MultipleDomain_WorksSuccessfully() throws {
        let rule = try XCTUnwrap(sut.parse(rule: "miloserdov.org,reneweconomy.com.au,wpneon.com###custom_html-10"))

        if case let Rule.elementHiding(domains, selector) = rule {
            XCTAssertNotNil(domains)
            let unwrapped = try XCTUnwrap(domains)
            XCTAssertEqual(unwrapped.count,3)
            XCTAssertEqual(selector, "#custom_html-10")
        }
    }

    func testParsingElementHidingRules_NoDomain_WorksSuccessfully() throws {
        let rule = try XCTUnwrap(sut.parse(rule: "## .custom_html-10"))

        if case let Rule.elementHiding(domains, selector) = rule {
            XCTAssertNil(domains)
            XCTAssertEqual(selector, ".custom_html-10")
        }

        XCTAssertNotNil(rule, "Element Hiding rules with a single domain should parse successfully.")
    }
}
