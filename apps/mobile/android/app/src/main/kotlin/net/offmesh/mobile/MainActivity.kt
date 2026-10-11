package net.offmesh.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bridge: EngineBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = EngineBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onStop() {
        bridge?.cancelNetwork()
        super.onStop()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bridge?.close()
        bridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
