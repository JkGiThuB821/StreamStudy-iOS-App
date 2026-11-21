# StreamStudy

StreamStudy turns university subjects into a streaming-style study planner. Each subject is a **series** and each topic an **episode**. The app finds videos, articles and documentation for every topic, builds AI lesson plans, tracks progress, and sends deadline reminders.

FIT3178 iOS App Development, Monash University. Built by Joy Jasmine Kaur.

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

The source code has been made public with permission from the university faculty after the unit was completed.

## Screenshots from the App

<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/bdc81698-f456-4f63-a899-89a868ac8411" width="220" alt="Screenshot 1"></td>
    <td><img src="https://github.com/user-attachments/assets/0706c71c-7b1b-41ae-a83b-f1b8c928a876" width="220" alt="Screenshot 2"></td>
    <td><img src="https://github.com/user-attachments/assets/9cf6e44b-2d2b-4263-86db-06ed35b1cc87" width="220" alt="Screenshot 3"></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/fa7b877a-11a1-4ddc-a765-fa376db958c4" width="220" alt="Screenshot 4"></td>
    <td><img src="https://github.com/user-attachments/assets/8af65d2f-41f6-40ef-8530-5f69b3e5150a" width="220" alt="Screenshot 5"></td>
    <td><img src="https://github.com/user-attachments/assets/ad72f202-d08c-4576-a9e7-d7953969c682" width="220" alt="Screenshot 6"></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/e3724a40-ad8b-41d1-8525-98558c93eda6" width="220" alt="Screenshot 7"></td>
    <td><img src="https://github.com/user-attachments/assets/c007732a-31da-4336-a25a-cb1f98957248" width="220" alt="Screenshot 8"></td>
    <td><img src="https://github.com/user-attachments/assets/d89ec1ae-ae63-4c84-b540-0ea6304fab48" width="220" alt="Screenshot 9"></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/9490d3c1-2b12-4cab-9945-fcbbca3e85c0" width="220" alt="Screenshot 10"></td>
    <td><img src="https://github.com/user-attachments/assets/a37d13e6-f394-47de-8157-3af0573b4fb0" width="220" alt="Screenshot 11"></td>
    <td><img src="https://github.com/user-attachments/assets/b140ec81-28c1-44b0-07f4-5e6713e48357" width="220" alt="Screenshot 12"></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/45f72f71-1bed-43e5-8935-12014374609f" width="220" alt="Screenshot 13"></td>
    <td><img src="https://github.com/user-attachments/assets/94306415-cf4a-496e-a09d-5f8a96b67408" width="220" alt="Screenshot 14"></td>
    <td><img src="https://github.com/user-attachments/assets/d11fff0a-975a-4088-a1e0-c7f420c33865" width="220" alt="Screenshot 15"></td>
  </tr>
</table>
