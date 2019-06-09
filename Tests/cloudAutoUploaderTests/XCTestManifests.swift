import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(gcloud_watcherTests.allTests),
    ]
}
#endif
