## Version 4.1.0-beta.1

This document contains the following sections:

1. [Requirements](#requirements)
2. [Setup](#setup)
3. [Advanced Setup](#advancedsetup)   
  1. [Setup with CocoaPods](#cocoapods)
  2. [Crash Reporting](#crashreporting)
  3. [User Metrics](#user-metrics)
  4. [In-App-Updates (Beta & Enterprise only)](#betaupdates)
  5. [Debug information](#debuginfo)
4. [Documentation](#documentation)  
5. [Troubleshooting](#troubleshooting)
6. [Contributing](#contributing)
7. [Contributor License](#contributorlicense)
8. [Contact](#contact)

<a id="requirements"></a> 
## 1. Requirements

1. We assume that you already have a project in Xcode, and that this project is opened in Xcode 7 or later.
2. The SDK supports tvOS 9.0 and later.

**[NOTE]** 
Be aware that tvOS requires Bitcode.

<a id="setup"></a>
## 2. Setup

We recommend integration of our binary into your Xcode project to setup HockeySDK for your tvOS app.

### 2.1 Obtain an App Identifier

Please see the "[How to create a new app](http://support.hockeyapp.net/kb/about-general-faq/how-to-create-a-new-app)" tutorial. This will provide you with an HockeyApp-specific App Identifier to be used to initialize the SDK.

### 2.2 Download the SDK

1. Download the latest [HockeySDK-tvOS](http://www.hockeyapp.net/releases/) framework, provided as a Zip file.
2. Unzip the file. You will see a folder named `HockeySDK-tvOS`. (Be sure not to use 3rd-party unzip tools!)

### 2.3 Copy the SDK into your project directory in Finder

Move the unzipped `HockeySDK-tvOS` folder into your project directory. In our experience, most projects will have a directory specifically set aside for 3rd-party libraries. These instructions assume that your project has such a directory, and that it is called `Vendor`.

<a id="setupxcode"></a>
### 2.4 Set up the SDK in Xcode

1. We recommend creating a group in your Xcode project for 3rd-party libraries, similar to the structure of the files on disk. In this case, the group will be called `Vendor`, matching the directory.
2. Make sure the `Project Navigator` is visible (⌘+1)
3. Drag & drop `HockeySDK.framework` from your window in `Finder` (this would be the `Vendor` directory) into your project in Xcode, and move it to the desired location in the `Project Navigator` (e.g., into the group called `Vendor`)
4. A sheet will appear. Select `Create groups for any added folders`, and check the checkbox for your target. Be sure to select your tvOS target if you have more than one. Now click `Finish`.

<a id="modifycode"></a>
### 2.5 Integrate the SDK into your code 

**Objective-C**

1. Open the file containing your app delegate (`AppDelegate.m` in a default project).
2. Add the following line below your own `import` statements:

  ```objectivec
  @import HockeySDK;
  ```

3. In the method `application:didFinishLaunchingWithOptions:`, add the following lines to initialize and start the HockeySDK:

  ```objectivec
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];
  // Do additional configuration if needed here
  [[BITHockeyManager sharedHockeyManager] startManager];
  [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
  ```

**Swift**

1. Open the file containing your app delegate (`AppDelegate.swift` in a default project).
2. Add the following line below your own `import` statements:

  ```swift
  import HockeySDK
  ```

3. In the method `application(application: UIApplication, didFinishLaunchingWithOptions launchOptions:[NSObject: AnyObject]?) -> Bool`, add the following lines to initialize and start the HockeySDK:

  ```swift
  BITHockeyManager.sharedHockeyManager().configureWithIdentifier("APP_IDENTIFIER")
  // Do additional configuration if needed here
  BITHockeyManager.sharedHockeyManager().startManager()
  BITHockeyManager.sharedHockeyManager().authenticator.authenticateInstallation() // This line is obsolete in the crash only builds
  ```

*Note:* The SDK has been optimized to defer as much initialization as it can until needed,  while still making sure that crashes on startup can be caught. Each module executes other code with a delay of up to several seconds. This ensures that your startup method will execute as fast as possible and that the SDK will not block the launch process (which would be a poor user experience and potentially result in your app being killed by the system watchdog process).

### 2.6 Bitcode

Make sure to read the [article in our knowledgebase about Bitcode](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/how-to-solve-symbolication-problems#bitcode) to make sure your crashes are symbolicated correctly.

**Congratulations, you're all set to use HockeySDK!**

<a id="advancedsetup"></a> 
## 3. Advanced Setup

<a id="cocoapods"></a>
### 3.1 Setup with CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like HockeySDK in your projects. To learn how to setup CocoaPods for your project, visit the [official CocoaPods website](http://cocoapods.org/).

**Podfile**

```ruby
platform :tvos, '9.0'
pod 'HockeySDK-tvOS', '~> 4.1.0-beta.1' 
```

<a id="crashreporting"></a> 
### 3.2 Crash Reporting Features

As the current release we provide is an beta version, crash reporting currently has limited confiuration and fine-tuning options.

#### 3.2.1 Disable Crash Reporting
The HockeySDK enables crash reporting **by default**. Crashes will be immediately sent to the server the next time the app is launched.

To provide you with the best crash reporting, we use a custom for of Plausible Labs' [PLCrashReporter]("https://github.com/bitstadium/PLCrashReporter") at [ Commit b1b94c016f9661af13bdf6295c3cd55cc7d6a56f]("https://github.com/bitstadium/PLCrashReporter/commit/b1b94c016f9661af13bdf6295c3cd55cc7d6a56f").

This feature can be disabled with the following code:

**Objective-C**

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];
[[BITHockeyManager sharedHockeyManager] setDisableCrashManager:YES]; //disable crash reporting
[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.sharedHockeyManager().configureWithIdentifier("APP_IDENTIFIER")
BITHockeyManager.sharedHockeyManager().disableCrashManager = true
BITHockeyManager.sharedHockeyManager().startManager()
```

#### 3.2.2 How are crash reports sent to HockeyApp?

Crashes are sent the next time the app starts, without any user interaction.

The SDK deliverably avoids sending the reports at the time of the crash, as it is not possible to implement such a mechanism safely. In particular, there is no way to do network access in an async-safe fashion without causing a severe drain on the device's resources, and any error whatsoever creates the danger of a double-fault or deadlock, resulting in losing the crash report entirely. We have found that users do relaunch the app, because most don't know what happened, and you will receive the vast majority of crash reports.

Sending pending crash reports on startup is done asynchronously, using `NSURLSession`. This avoids any issues with slow startup and is resilient against poor network connectivity.

#### 3.2.4 Attach additional data

The `BITHockeyManagerDelegate` protocol provides methods to add additional data to a crash report:

1. UserID: `- (NSString *)userIDForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`
2. UserName: `- (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`
3. UserEmail: `- (NSString *)userEmailForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`

The `BITCrashManagerDelegate` protocol (which is automatically included in `BITHockeyManagerDelegate`) provides methods to add more crash specific data to a crash report:

1. Text attachments: `-(NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager`

  Check the following tutorial for an example on how to add CocoaLumberjack log data: [How to Add Application Specific Log Data on iOS or OS X](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/how-to-add-application-specific-log-data-on-ios-or-os-x)
2. Binary attachments: `-(BITHockeyAttachment *)attachmentForCrashManager:(BITCrashManager *)crashManager`

Make sure to implement the protocol

```objectivec
@interface YourAppDelegate () <BITHockeyManagerDelegate> {}

@end
```

and set the delegate:

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDelegate: self];

[[BITHockeyManager sharedHockeyManager] startManager];
```

<a name="user-metrics"></a>
### 3.3 Metrics

HockeyApp automatically provides you with nice, intelligible, and informative metrics about how your app is used and by whom. 
- **Sessions**: A new session is tracked by the SDK whenever the containing app is restarted (this refers to a 'cold start', i.e. when the app has not already been in memory prior to being launched) or whenever it becomes active again after having been in the background for 20 seconds or more.
- **Users**: The SDK anonymously tracks the users of your app by creating a random UUID that is then securely stored in the iOS keychain. Because this anonymous ID is stored in the keychain it persists across reinstallations.
- **Custom Events**: If you are part of [Preseason](https://www.hockeyapp.net/preseason/), you can now track Custom Events in your app, understand user actions and see the aggregates on the HockeyApp portal.

Just in case you want to opt-out of the automatic collection of anonymous users and sessions statistics, there is a way to turn this functionality off at any time:

```objectivec
[BITHockeyManager sharedHockeyManager].disableMetricsManager = YES;
```

#### 3.3.1 Custom Events

By tracking custom events, you can now get insight into how your customers use your app, understand their behavior and answer important business or user experience questions while improving your app.

- Before starting to track events, ask yourself the questions that you want to get answers to. For instance, you might be interested in business, performance/quality or user experience aspects.
- Name your events in a meaningful way and keep in mind that you will use these names when searching for events in the HockeyApp web portal. It is your reponsibility to not collect personal information as part of the events tracking.

**Objective-C**

```objectivec
BITMetricsManager *metricsManager = [BITHockeyManager sharedHockeyManager].metricsManager;

[metricsManager trackEventWithName:eventName]
```

**Swift**

```swift
let metricsManager = BITHockeyManager.sharedHockeyManager().metricsManager

metricsManager.trackEventWithName(eventName)
```

**Limitations**

- Accepted characters for tracking events are: [a-zA-Z0-9_. -]. If you use other than the accepted characters, your events will not show up in the HockeyApp web portal.
- There is currently a limit of 300 unique event names per app per week.
- There is _no_ limit on the number of times an event can happen.

<a name="betaupdates"></a>
### 3.4 In-App-Update notifications (Beta & Enterprise only)

The following options only show some of possibilities to interact and fine-tune the update feature when using Ad-Hoc or Enterprise provisioning profiles. For more please check the full documentation of the `BITUpdateManager` class in our [documentation](#documentation).

The feature presents update and version information in  pop over window.

This module automatically disables itself when running in an App Store build by default!

In-App-Update notifications can be disabled manually as follows:

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDisableUpdateManager: YES]; //disable auto updating

[[BITHockeyManager sharedHockeyManager] startManager];
```

<a id="debuginfo"></a>
### 3.5 Debug Information

To check if data was sent properly to HockeyApp and also see some additional SDK debug loggging data in the console, add the following line before `startManager`:

**Objective-C**

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];
[BITHockeyManager sharedHockeyManager].logLevel = BITLogLevelDebug;
[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.sharedHockeyManager().configureWithIdentifier("APP_IDENTIFIER")
BITHockeyManager.sharedHockeyManager().debugLogEnabled = true
BITHockeyManager.sharedHockeyManager().startManager()
```

<a id="documentation"></a>
## 4. Documentation

Our documentation can be found at [HockeyApp](http://hockeyapp.net/help/sdk/tvos/4.1.0-beta.1/index.html).

<a id="troubleshooting"></a>
## 5.Troubleshooting

1. iTunes Connect rejection

  Make sure none of the following files are copied into your app bundle. This can be checked by examining the `Copy Bundle Resources` item in the `Build Phases` tab of your app target in the Xcode project, or by looking within the final `.app` bundle after making your build:

  - `HockeySDK.framework` (unless you've built your own version of the SDK as a dynamic framework - if you don't know what this means, you don't have to worry about it)
  - `de.bitstadium.HockeySDK-tvOS-1.0-Beta.2.docset`

2. Features not working as expected

  Enable debug output to the console to see additional information from the SDK as it initializes modules, sends and receives network requests, and more, by adding the following code before calling `startManager`:

	`[BITHockeyManager sharedHockeyManager].logLevel = BITLogLevelDebug;`

<a id="contributing"></a>
## 6. Contributing

We're looking forward to your contributions via pull requests.

**Development environment**

* Any Mac running the latest version of OS X (10.11 El Capitan at the time of this writing)
* Get the latest Xcode (7.1 at the time of this writing) from the Mac App Store
* [AppleDoc](https://github.com/tomaz/appledoc) 

<a id="contributorlicense"></a>
## 7. Contributor License

You must sign a [Contributor License Agreement](https://cla.microsoft.com/) before opening a pull request. To complete the Contributor License Agreement (CLA), you must submit a request via [this form](https://cla.microsoft.com/), then electronically sign the CLA once you receive the email containing the link to the document. Signing the CLA once, for any project, covers all submissions to all Microsoft OSS projects, unless otherwise noted.

<a id="contact"></a>
## 8. Contact

If you have further questions or run into trouble that cannot be resolved by any of the information here, feel free to open a Github issue, or contact us at [support@hockeyapp.net](mailto:support@hockeyapp.net).
