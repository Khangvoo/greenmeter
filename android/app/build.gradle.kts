plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.tree_measure_app"
    compileSdk = rootProject.ext.get("compileSdkVersion") as Int
    ndkVersion = "27.0.12077973"

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = rootProject.ext.get("javaCompatibilityVersion") as JavaVersion
        targetCompatibility = rootProject.ext.get("javaCompatibilityVersion") as JavaVersion
    }

    kotlinOptions {
        jvmTarget = rootProject.ext.get("kotlinJvmTarget") as String
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.tree_measure_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = rootProject.ext.get("minSdkVersion") as Int
        targetSdk = rootProject.ext.get("targetSdkVersion") as Int
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("String", "SERVER_CLIENT_ID", "\"925288608201-fvuocrstd1altg650dap7bvvp31o4ut1.apps.googleusercontent.com\"")
    }

    sourceSets {
        getByName("main") {
            assets.srcDirs("src/main/assets")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
