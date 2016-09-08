## Version 4.1.0

- [NEW] Add ability to track custom events
- [NEW] Additional API to track an event with properties and measurements.
- [BUGFIX] Add Bitcode marker back to simulator slices. This is necessary because otherwise `lipo` apparently strips the Bitcode sections from the merged library completely. As a side effect, this unfortunately breaks compatibility with Xcode 6. [#310](https://github.com/bitstadium/HockeySDK-iOS/pull/310)
- Minor fixes and refactorings

## Version 4.1.0-beta.1

- [IMPROVEMENT] Prevent User Metrics from being sent if `BITMetricsManager` has been disabled.

## Version 4.0.0

- [IMPROVEMENT] Prefix GZIP category on NSData to prevent symbol collisions
- [BUGFIX] Exclude GZIP functionality from none metrics builds

## Version 1.2.0-alpha.1

- [NEW] Add ability to track custom events
- [BUGFIX] Server URL is now properly customizable
- [BUGFIX] Fix memory leak in networking code
- [BUGFIX] Fix different bugs in the events sending pipeline
- [IMPROVEMENT] Events are always persisted, even if the app crashes
- [IMPROVEMENT] Allow disabling `BITMetricsManager` at any time
- [IMPROVEMENT] Reuse `NSURLSession` object
- [IMPROVEMENT] Under the hood improvements and cleanup

## Version 1.1.0-beta.1

- [NEW] User Metrics including users and sessions data is now in public beta

## Version 1.1.0-alpha.1

- [NEW] Add User Metrics support
- [UPDATE] Add improvements and fixes from 1.0.0-beta.2

## Version 1.0.0-beta.2

- [FIX] Add userPath anonymization
- [FIX] Remove unnecessary calls to -[NSUserDefaults synchronize]
- [FIX] Fix NSURLSession memory leak
- [FIX] Minor refactorings & bug fixes

## Version 1.0.0-beta.1

- [NEW] Added support for beta update notifications
- [NEW] Added support for authentication

## Version 1.0.0-alpha.1

- [NEW] `BITCrashManager`: Added tvOS support
