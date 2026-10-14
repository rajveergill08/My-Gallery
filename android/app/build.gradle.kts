plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mygallery.my_gallery"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mygallery.my_gallery"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // This local build is installable on a phone. Configure a private
            // upload key before publishing the app to an app store.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Flutter's command-line tool looks for the finished APK under the project's
// conventional build folder. Gradle builds outside OneDrive (see the root
// build script), so mirror only the final APK back to that expected location.
val flutterExpectedApkDirectory =
    rootProject.projectDir.parentFile.resolve("build/app/outputs/flutter-apk")

tasks.matching {
    it.name == "assembleDebug" ||
        it.name == "assembleProfile" ||
        it.name == "assembleRelease"
}.configureEach {
    val variant = name.removePrefix("assemble").lowercase()
    doLast {
        project.copy {
            from(layout.buildDirectory.dir("outputs/apk/$variant"))
            include("*.apk")
            into(flutterExpectedApkDirectory)
        }
    }
}
