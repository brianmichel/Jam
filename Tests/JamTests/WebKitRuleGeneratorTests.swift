import XCTest
@testable import Jam
import WebKit

final class WebKitRuleGeneratorTests: XCTestCase {
    let parser = RuleParser()
    let sut = WebKitRuleGenerator()

    func testRulesAreGeneratedWithNoOptions() throws {
        let rule = try XCTUnwrap(parser.parse(rule: ".com/ad/"))
        let output = sut.generate(for: [rule])

        XCTAssertTrue(output.count == 1, "There should be one rule block per rule.")
        XCTAssertNotNil(output, "Output should never be nil for valid input.")

        let first = output[0]
//        let action = try XCTUnwrap((first["action"] as! [String: Any])["type"] as? String)
//        XCTAssertEqual(action, "block", "The action should be block for url rules.")
//        XCTAssertEqual((first["trigger"] as! [String: String])["url-filter"], rule.trigger, "The regex from the rule should match the url-filter.")
    }

//    func testRulesAreGeneratedWithOptions() throws {
//        let rule = try XCTUnwrap(parser.parse(rule: ".com/ad/$~image,document,domain=~mediaplex.com|~warpwire.com"))
//        let output = sut.generate(for: [rule])
//
//        XCTAssertTrue(output.count == 1, "There should be one rule block per rule.")
//        let first = output[0]
//        let unlessDomain = try XCTUnwrap((first["trigger"] as! [String: Any])["unless-domain"] as? [String])
//        let resourceTypes = try XCTUnwrap((first["trigger"] as! [String: Any])["resource-type"] as? [String])
//
//        XCTAssertEqual(Set(unlessDomain), Set(["mediaplex.com", "warpwire.com"]), "Options should be correctly translated to the filter from the rule.")
//        XCTAssertEqual(resourceTypes, ["document"], "Options for resource-type should be correctly translated to the filter from the rule.")
//    }
//
//    func testMultipleRulesAreGeneratedCorrectly() throws {
//        let rule1 = try XCTUnwrap(parser.parse(rule: ".com/ad/$~image,document,domain=~mediaplex.com|~warpwire.com"))
//        let rule2 = try XCTUnwrap(parser.parse(rule: ".com/ad/"))
//        let output = sut.generate(for: [rule1, rule2])
//
//        XCTAssertTrue(output.count == 2, "There should be one rule block per rule.")
//    }
//
//    func testRulesSuccessfullyCompile() throws {
//        let rule1 = try XCTUnwrap(parser.parse(rule: ".com/ad/$~image,document,domain=~mediaplex.com|~warpwire.com"))
//        let rule2 = try XCTUnwrap(parser.parse(rule: ".com/ad/"))
//        let output = sut.generate(for: [rule1, rule2])
//        let jsonData = try JSONSerialization.data(withJSONObject: output)
//        let jsonString = String(data: jsonData, encoding: .utf8)
//
//        let identifier = UUID().uuidString
//        let expectation = XCTestExpectation(description: "successful-list-compilation")
//        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: jsonString) { list, error in
//            XCTAssertNil(error, "There should not be any errors when compiling the WebKit generated list.")
//            XCTAssertNotNil(list, "The list should successful be compiled.")
//            XCTAssertEqual(identifier, list!.identifier, "The identifier of the list should match the passed in identifier.")
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: 0.5)
//    }
//
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
            let list = try await WKContentRuleListStore.default().compileContentRuleList(
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
