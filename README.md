# StreamStudy

StreamStudy turns university subjects into a streaming-style study planner. Each subject is a **series** and each topic an **episode**. The app finds videos, articles and documentation for every topic, builds AI lesson plans, tracks progress, and sends deadline reminders.

FIT3178 iOS App Development, Monash University. Built by Joy Jasmine Kaur (33494266).

## Features

- **Subjects and topics:** create subjects with an icon and colour, then add topics with optional search tags.
- **Resource discovery:** finds study videos (YouTube Data API) and articles (dev.to) for each topic. Gemini tags each resource and ranks it by relevance.
- **AI lesson plans:** Gemini builds a step-by-step plan for a topic. If Gemini is unavailable or the device is offline, an on-device plan is used instead.
- **Progress dashboard:** Swift Charts views of study time, completed topics and how well you understood each topic.
- **Calendar and deadlines:** deadlines with priorities, plus local reminder notifications.
- **Season Pass:** Swipe-to-Revise cards, a Weekly Digest notification that opens the digest when tapped, and an animated Season Recap.
- **Accounts and sync:** Firebase email sign-in, with SwiftData on the device synced to Cloud Firestore.
- **Offline support:** a connection banner, cached data, and changes are uploaded when the connection returns.
- **Accessibility:** VoiceOver labels, values and hints, Dynamic Type through `@ScaledMetric` and adaptive layouts, Reduce Motion support, touch targets of at least 44 pt, and Light/Dark Mode.
- **Privacy:** an in-app privacy policy, a privacy manifest (`PrivacyInfo.xcprivacy`), and in-app account deletion (App Store Guideline 5.1.1(v)).

## Account data and switching accounts

- **Signing in:** the account's data is downloaded from Firestore and replaces whatever is on the device.
- **Signing out:**
  - the app first uploads your latest changes;
  - it then removes that account's data and pending reminders from the device, so the next account starts empty;
  - if you're offline, or the upload fails, it warns you before signing out.
- **Weekly Digests** are only stored on the device, so signing out removes them.
- **Deleting your account** (Account → Delete Account) asks for your password. It then removes all of your Firestore data, the data on this device, your reminders, and the Firebase account itself.

## Requirements

- Xcode 16.4 or later. The project was made with Xcode 26, and it also runs on Xcode 16.4.
- iOS 17.6 or later. On Xcode 16.4, set **iOS Deployment Target** to 17.6 for both the app and test targets.
- A Firebase project with Email/Password Authentication and Cloud Firestore enabled.
- A YouTube Data API v3 key. A Gemini API key is optional: without one, the app uses on-device lesson plans and tagging.

## Setup

1. Clone the repository and open `final-app.xcodeproj`.
2. **Firebase:** download `GoogleService-Info.plist` from your Firebase project and drag it into the `final-app` folder in Xcode, with the **final-app** target ticked. This file is not committed.
3. **API keys:** create `final-app/Config/Secrets.xcconfig`, which is also not committed:
   ```
   YOUTUBE_API_KEY = your_youtube_key
   GEMINI_API_KEY = your_gemini_key
   ```
4. The Firebase packages are fetched through Swift Package Manager when the project opens. If they aren't, choose **File → Packages → Resolve Package Versions**.
5. Pick an iPhone simulator, then choose **Product → Run**.

## Demo tools

The Account screen includes developer tools for the demo:
- **Load Demo Data:** adds sample subjects, history, ratings, deadlines and weekly drops.
- **Show Onboarding Again**
- **Test Reminder** and **Test Weekly Drop**, in the Notifications tab

These would be removed or hidden before an App Store release.

## Tests

Choose **Product → Test**. The unit tests in `final-appTests` cover:
- deep links
- lesson plans
- network services, using a stubbed `URLSession`
- the recommendation engine
- the search planner
- the Season Pass features
- feedback-driven changes

## Project structure

```
final-app/
  App/          App entry point and RootView (sign-in, onboarding and sync)
  Config/       APIKeys and Secrets.xcconfig
  Models/       SwiftData models
  Services/     Auth, Firestore sync, YouTube, dev.to, Gemini, notifications, recommendations
  Utilities/    Design system and form helpers
  Views/        Home, Subjects, Calendar, Progress, Season Pass, Account, Auth, Onboarding
final-appTests/ Unit tests
```

## Acknowledgements

- [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk) (Apache 2.0)
- [YouTube Data API v3](https://developers.google.com/youtube/v3)
- [DEV Community (Forem) API](https://developers.forem.com/api)
- [Google Gemini API](https://ai.google.dev/gemini-api/docs)
- [Space Grotesk](https://fonts.google.com/specimen/Space+Grotesk) by Florian Karsten (SIL Open Font License 1.1)
- SF Symbols, Apple Developer Documentation, Hacking with Swift, and the FIT3178 unit materials
- Claude (Anthropic) helped with parts of the code and documentation. I reviewed all of it and understand it.

The full credits are also in the app, under Account → About StreamStudy.
