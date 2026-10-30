plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (push notifications) switches on automatically once google-services.json is added
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Permanent signing key, supplied by the GitHub build from repository secrets
val releaseKeystore = System.getenv("CS_KEYSTORE_PATH")?.let { file(it) }

android {
    namespace = "com.sagar.fleet_management.fleet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.chakkasaarthi.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (releaseKeystore != null && releaseKeystore.exists()) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = System.getenv("CS_KEYSTORE_PASSWORD")
                keyAlias = "chakka-saarthi"
                keyPassword = System.getenv("CS_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Same key every build, so updates install over the old app.
            // Falls back to a temporary key only if the secrets are missing.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
