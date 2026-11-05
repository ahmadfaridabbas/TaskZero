import XCTest
@testable import TaskZero

final class CleanupConfigurationTests: XCTestCase {
    func testTimeoutsAreClampedToTheAllowedRange() {
        var configuration = CleanupConfiguration()

        configuration.gracefulTerminationTimeout = -10
        XCTAssertEqual(configuration.gracefulTerminationTimeout, CleanupConfiguration.minimumTimeout)

        configuration.gracefulTerminationTimeout = 9_999
        XCTAssertEqual(configuration.gracefulTerminationTimeout, CleanupConfiguration.maximumTimeout)

        configuration.backgroundProcessTimeout = 0
        XCTAssertEqual(configuration.backgroundProcessTimeout, CleanupConfiguration.minimumTimeout)

        configuration.backgroundProcessTimeout = 7
        XCTAssertEqual(configuration.backgroundProcessTimeout, 7)
    }

    func testDecodingClampsOutOfRangeStoredTimeouts() throws {
        let json = """
        {
          "gracefulTerminationTimeout": 100000,
          "backgroundProcessTimeout": -5,
          "enableForceTermination": true,
          "includeBackgroundProcesses": true,
          "showProcessPreview": true,
          "showCleanupConfirmation": true,
          "showNotifications": true,
          "automaticallyDisplaySummary": true,
          "launchAtLogin": false,
          "startInMenuBarMode": true,
          "appearance": "system"
        }
        """
        let decoded = try JSONDecoder().decode(CleanupConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.gracefulTerminationTimeout, CleanupConfiguration.maximumTimeout)
        XCTAssertEqual(decoded.backgroundProcessTimeout, CleanupConfiguration.minimumTimeout)
    }

    func testRoundTripEncodingPreservesValues() throws {
        var configuration = CleanupConfiguration()
        configuration.gracefulTerminationTimeout = 8
        configuration.backgroundProcessTimeout = 3
        configuration.enableForceTermination = false
        configuration.appearance = .dark

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(CleanupConfiguration.self, from: data)

        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(decoded.gracefulTerminationTimeout, 8)
        XCTAssertEqual(decoded.backgroundProcessTimeout, 3)
        XCTAssertFalse(decoded.enableForceTermination)
        XCTAssertEqual(decoded.appearance, .dark)
    }
}
