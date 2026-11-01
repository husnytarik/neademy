import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yayın imzası: android/key.properties (yerel) ya da CI'nin yazdığı aynı dosya. Dosya yoksa debug imzası kullanılır.
val imzaAyarlari = Properties().apply {
    val dosya = rootProject.file("key.properties")
    if (dosya.exists()) dosya.inputStream().use { load(it) }
}

android {
    namespace = "com.neademy.neademy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.neademy.neademy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (imzaAyarlari.isNotEmpty()) {
            create("release") {
                storeFile = rootProject.file(imzaAyarlari.getProperty("storeFile"))
                storePassword = imzaAyarlari.getProperty("storePassword")
                keyAlias = imzaAyarlari.getProperty("keyAlias")
                keyPassword = imzaAyarlari.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (imzaAyarlari.isNotEmpty()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
