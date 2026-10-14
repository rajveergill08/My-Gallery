# MyGallery

MyGallery is a private, offline Android photo and video gallery built with
Flutter and Material 3. It reads only the media the user allows through
Android's system photo permissions. Photos, videos, favourites, settings, and
search history stay on the device.

## Included features

- Animated splash screen and first-launch onboarding
- Android 13+ photo/video permissions and Android 14+ selected-media access
- Real device albums, recent media, photos, videos, and favourites
- Paginated thumbnail grids designed for large galleries
- Photo zoom/swipe viewer and local video player
- Search by media filename and album name
- Persistent favourites, appearance, grid, sort, and privacy settings
- Multi-select, Android sharing, and system-approved trash/delete flow
- Light, dark, and system themes

## Run from VS Code or Android Studio

Connect an Android phone with USB debugging enabled, then run:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

In VS Code, open this folder, choose the phone from the device selector, and
press `F5`. In Android Studio, choose **Open**, select this folder, wait for the
Flutter packages to finish loading, select the phone, and click **Run**.

## Connect an Android phone

1. On the phone, open **Settings > About phone** and tap **Build number** seven
   times.
2. Open **Developer options** and enable **USB debugging**.
3. Connect the phone with a data-capable USB cable and choose **File transfer**
   if prompted.
4. Accept the phone's **Allow USB debugging** dialog.
5. Confirm the connection with `flutter devices`, then use `flutter run`.

## Build an installable APK

```powershell
flutter build apk --release
```

This project keeps Android build output outside OneDrive on Windows to avoid a
Gradle reparse-point error, then copies the final APK back to Flutter's normal
`build/app/outputs/flutter-apk/app-release.apk` path. The installable APK
supplied with this project is in `dist/MyGallery-release.apk`. Copy that file
to your phone, open it in the Files app, and allow installation from that file
source if Android prompts you. The current local release is signed with a
development key and is intended for direct phone testing.

## Common customizations

- App name: `android/app/src/main/AndroidManifest.xml` (`android:label`)
- Android package ID: `android/app/build.gradle.kts` (`applicationId`)
- App icon: replace `assets/branding/mygallery_icon.png` and the
  `android/app/src/main/res/mipmap-*/ic_launcher.png` launcher sizes
- Theme colors and component styling: `lib/theme/app_theme.dart`
- Permission flow: `lib/services/permission_service.dart` and
  `lib/screens/permission_screen.dart`
- Android permission declarations: `android/app/src/main/AndroidManifest.xml`
- Home screen: `lib/screens/home_screen.dart`
- Recents, photos, and videos: `lib/screens/recents_screen.dart`,
  `lib/screens/all_photos_screen.dart`, and `lib/screens/videos_screen.dart`
- Favourites and albums: `lib/screens/favourites_screen.dart`,
  `lib/screens/albums_screen.dart`, and `lib/screens/album_detail_screen.dart`

Before publishing to Google Play, replace the local debug signing key in
`android/app/build.gradle.kts` with your own private release/upload key.
