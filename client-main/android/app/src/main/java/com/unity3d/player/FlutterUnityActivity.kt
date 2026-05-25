package com.unity3d.player

import io.flutter.embedding.android.FlutterActivity

open class FlutterUnityActivity : FlutterActivity(), IUnityPlayerLifecycleEvents {

    var mUnityPlayer: FlutterUnityPlayer? = null

    override fun onUnityPlayerUnloaded() {
        moveTaskToBack(true)
    }

    override fun onUnityPlayerQuitted() {}
}