plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// google-services.json이 있을 때만 Firebase 플러그인 적용 (로컬 개발 시 파일 없어도 빌드 가능)
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// flutter_unity_widget가 app/libs/unity-classes.jar 경로를 참조하므로
// unityLibrary/libs/unity-classes.jar 를 app/libs/ 로 복사 (configuration 단계에서 즉시 실행).
run {
    val source = file("../unityLibrary/libs/unity-classes.jar")
    if (source.exists()) {
        val targetDir = file("libs")
        targetDir.mkdirs()
        val target = File(targetDir, "unity-classes.jar")
        if (!target.exists() || target.lastModified() < source.lastModified()) {
            source.copyTo(target, overwrite = true)
        }
    }
}

android {
    namespace = "com.example.login_test"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }

    defaultConfig {
        applicationId = "com.example.login_test"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // unityLibrary 가 transitive 로 노출하는 unity-classes 를 제외 (app/libs/unity-classes.jar 와 중복 방지)
    api(project(":unityLibrary")) {
        exclude(module = "unity-classes")
    }
    runtimeOnly(project(":compat-stubs"))
    compileOnly(files("../unityLibrary/libs/unity-classes.jar"))
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}


flutter {
    source = "../.."
}
