import XCTest

import gcloud_watcherTests

var tests = [XCTestCaseEntry]()
tests += gcloud_watcherTests.allTests()
XCTMain(tests)
