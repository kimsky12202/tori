package android.window;

/**
 * Stub for android.window.OnBackInvokedCallback (added in Android 13, API 33).
 * Unity 2022.3 references this class via reflection even on older Android versions.
 * Without this stub, Unity's nativeRender() throws NoClassDefFoundError on API < 33,
 * causing a black screen every frame.
 *
 * At runtime on Android 13+ the real system class is used instead.
 */
public interface OnBackInvokedCallback {
    void onBackInvoked();
}