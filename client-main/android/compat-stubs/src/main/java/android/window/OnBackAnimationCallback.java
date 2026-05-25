package android.window;

/**
 * Stub for android.window.OnBackAnimationCallback (added in Android 14, API 34).
 * Preemptively added to prevent reflection failures if Unity references this type.
 */
public interface OnBackAnimationCallback extends OnBackInvokedCallback {
    default void onBackStarted(BackEvent backEvent) {}
    default void onBackProgressed(BackEvent backEvent) {}
    default void onBackCancelled() {}
}