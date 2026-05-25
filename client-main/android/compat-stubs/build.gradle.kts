plugins {
    id("com.android.library")
}

android {
    namespace = "com.example.login_test.compat"
    compileSdk = 32

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}
