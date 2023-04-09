import XCTest
@testable import Jam
import WebKit

final class WebKitRuleGeneratorTests: XCTestCase {
    let parser = RuleParser()
    let sut = WebKitRuleGenerator()

    func testRulesAreGeneratedWithNoOptions() throws {
        guard case let Rule.url(pattern: pattern, options: options, action: action) = try XCTUnwrap(parser.parse(rule: ".com/ad/")) else {
            XCTFail("Unable to parse rule")
            return
        }
        let output = sut.generate(for: [.url(pattern: pattern, options: options, action: action)])

        XCTAssertTrue(output.count == 1, "There should be one rule block per rule.")
        XCTAssertNotNil(output, "Output should never be nil for valid input.")

        let first = output[0]
        let actionType = try XCTUnwrap((first["action"] as! [String: Any])["type"] as? String)
        let trigger = try XCTUnwrap((first["trigger"] as? [String: AnyObject])?["url-filter"] as? String)
        XCTAssertEqual(actionType, "block", "The action should be block for url rules.")
        XCTAssertEqual(trigger, "^[^:]+:(//)?.*\\.com/ad/", "The regex from the rule should match the url-filter.")
    }

    func testRulesAreGeneratedWithOptions() throws {
        let rule = try XCTUnwrap(parser.parse(rule: ".com/ad/$~image,document,domain=mediaplex.com|warpwire.com"))
        let output = sut.generate(for: [rule])

        XCTAssertTrue(output.count == 1, "There should be one rule block per rule.")
        let first = output[0]
        let ifDomain = try XCTUnwrap((first["trigger"] as? [String: AnyObject])?["if-domain"] as? [String])
        let resourceTypes = try XCTUnwrap((first["trigger"] as? [String: AnyObject])?["resource-type"] as? [String])

        XCTAssertEqual(Set(ifDomain), Set(["mediaplex.com", "warpwire.com"]), "Options should be correctly translated to the filter from the rule.")

        let matchingSet = Set(["websocket", "font", "other", "fetch", "popup", "style-sheet", "media", "script", "ping"])
        XCTAssertEqual(Set(resourceTypes), matchingSet, "Options for resource-type should be correctly translated to the filter from the rule.")
    }

    func testMultipleRulesAreGeneratedCorrectly() throws {
        let rule1 = try XCTUnwrap(parser.parse(rule: ".com/ad/$~image,document,domain=~mediaplex.com|~warpwire.com"))
        let rule2 = try XCTUnwrap(parser.parse(rule: ".com/ad/"))
        let output = sut.generate(for: [rule1, rule2])

        XCTAssertTrue(output.count == 2, "There should be one rule block per rule.")
    }

    func testRulesSuccessfullyCompile() throws {
        let rule1 = try XCTUnwrap(parser.parse(rule: ".com/ad/$~image,document,domain=~mediaplex.com|~warpwire.com"))
        let rule2 = try XCTUnwrap(parser.parse(rule: ".com/ad/"))
        let output = sut.generate(for: [rule1, rule2])
        let jsonData = try JSONSerialization.data(withJSONObject: output)
        let jsonString = String(data: jsonData, encoding: .utf8)

        let identifier = UUID().uuidString
        let expectation = XCTestExpectation(description: "successful-list-compilation")
        WKContentRuleListStore
            .default()
            .compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: jsonString) { list, error in
                XCTAssertNil(error, "There should not be any errors when compiling the WebKit generated list.")
                XCTAssertNotNil(list, "The list should successful be compiled.")
                XCTAssertEqual(identifier, list!.identifier, "The identifier of the list should match the passed in identifier.")
                expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)
    }

    @MainActor
    func testRulesFromEasyListCompile() async throws {
        let path = try XCTUnwrap(Bundle.module.path(forResource: "easy-list", ofType: "txt"))
        let rules = await parser.parse(file: path)
        let output = sut.generate(for: rules)

        let jsonData = try JSONSerialization.data(withJSONObject: output)
        let jsonString = String(data: jsonData, encoding: .utf8)

        let identifier = UUID().uuidString
        do {
            // Looks like this has to be called on the @MainActor :(
            let list = try await WKContentRuleListStore
                .default()
                .compileContentRuleList(
                    forIdentifier: identifier,
                    encodedContentRuleList: jsonString
                )
            XCTAssertNotNil(list, "The list should successful be compiled.")
            XCTAssertEqual(identifier, list!.identifier, "The identifier of the list should match the passed in identifier.")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
