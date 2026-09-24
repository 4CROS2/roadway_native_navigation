package com.crossdev.roadway.roadway_native_navigation

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/*
 * Run with `./gradlew testDebugUnitTest` from a host application's `android/` directory.
 */

internal class RoadwayNativeNavigationPluginTest {
    @Test
    fun supportsMaterial3Expressive_fromAndroid16() {
        assertFalse(RoadwayNativeNavigationPlugin.supportsMaterial3Expressive(35))
        assertTrue(RoadwayNativeNavigationPlugin.supportsMaterial3Expressive(36))
    }

    @Test
    fun onMethodCall_getCapabilities_neverReportsLiquidGlass() {
        val plugin = RoadwayNativeNavigationPlugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("getCapabilities", null), result)

        // Unit tests run against android.jar stubs, where SDK_INT is 0.
        Mockito.verify(result).success(
            mapOf("liquidGlass" to false, "material3Expressive" to false),
        )
    }

    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val plugin = RoadwayNativeNavigationPlugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("unknown", null), result)

        Mockito.verify(result).notImplemented()
    }
}
