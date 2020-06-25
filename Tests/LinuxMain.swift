import XCTest

import x265_tests

var tests = [XCTestCaseEntry]()
tests += x265_tests.__allTests()

XCTMain(tests)
