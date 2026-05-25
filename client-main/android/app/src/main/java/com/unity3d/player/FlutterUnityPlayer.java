package com.unity3d.player;

import android.app.Activity;

public class FlutterUnityPlayer extends UnityPlayer {
    public FlutterUnityPlayer(Activity currentActivity, IUnityPlayerLifecycleEvents lifecycleEvents) {
        super(currentActivity, lifecycleEvents);
    }
}
