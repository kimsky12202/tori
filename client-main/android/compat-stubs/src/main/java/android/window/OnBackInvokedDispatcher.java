package android.window;

/**
 * Stub for android.window.OnBackInvokedDispatcher (added in Android 13, API 33).
 * Used by Unity 2022.3's predictive back gesture support via reflection.
 */
public class OnBackInvokedDispatcher {
    public static final int PRIORITY_DEFAULT = 0;
    public static final int PRIORITY_OVERLAY = 1000000;

    public void registerOnBackInvokedCallback(int priority, OnBackInvokedCallback callback) {}
    public void unregisterOnBackInvokedCallback(OnBackInvokedCallback callback) {}
}