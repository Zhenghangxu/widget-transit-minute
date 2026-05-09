import Foundation
import XCTest
@testable import TransitMinuteCore

final class GoogleErrorMessageTests: XCTestCase {
    func testBuildsReadableMessageFromGoogleErrorBody() {
        let data = Data("""
        {
          "error": {
            "code": 400,
            "message": "FieldMask contains invalid field.",
            "status": "INVALID_ARGUMENT"
          }
        }
        """.utf8)

        let message = GoogleErrorMessage.make(
            prefix: "Routes request failed",
            statusCode: 400,
            data: data
        )

        XCTAssertEqual(
            message,
            "Routes request failed with HTTP 400: FieldMask contains invalid field."
        )
    }
}
