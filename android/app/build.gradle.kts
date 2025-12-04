import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "pl.radiolicencja"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "pl.radiolicencja"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                    ?: error("Missing storeFile in key.properties")
                storePassword = keystoreProperties["storePassword"]?.toString()
                    ?: error("Missing storePassword in key.properties")
                keyAlias = keystoreProperties["keyAlias"]?.toString()
                    ?: error("Missing keyAlias in key.properties")
                keyPassword = keystoreProperties["keyPassword"]?.toString()
                    ?: error("Missing keyPassword in key.properties")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

val isReleaseTaskRequested = gradle.startParameter.taskRequests.any { request ->
    request.args.any { it.contains("Release", ignoreCase = true) }
}

if (!hasReleaseKeystore && isReleaseTaskRequested) {
    throw GradleException(
        "Missing key.properties for release signing. Provide the Play upload keystore credentials."
    )
}
