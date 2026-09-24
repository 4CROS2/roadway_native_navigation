package com.crossdev.roadway.roadway_native_navigation

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.view.ContextThemeWrapper
import android.view.View
import androidx.appcompat.content.res.AppCompatResources
import com.google.android.material.bottomnavigation.BottomNavigationView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

class RoadwayNativeNavigationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            NativeNavigationBarFactory(binding.binaryMessenger),
        )
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "getCapabilities") {
            result.notImplemented()
            return
        }
        result.success(
            mapOf(
                "liquidGlass" to false,
                "material3Expressive" to supportsMaterial3Expressive(),
            ),
        )
    }

    internal companion object {
        const val VIEW_TYPE = "roadway_native_navigation/navigation_bar"
        const val CHANNEL = "roadway_native_navigation"

        /** Material 3 Expressive is the system design from Android 16 (API 36). */
        fun supportsMaterial3Expressive(sdkInt: Int = Build.VERSION.SDK_INT): Boolean =
            sdkInt >= Build.VERSION_CODES.BAKLAVA
    }
}

private class NativeNavigationBarFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativeNavigationBarPlatformView(context, messenger, viewId, args)
    }
}

private class NativeNavigationBarPlatformView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    args: Any?,
) : PlatformView {
    private val navigationView = BottomNavigationView(
        if (args.material3Expressive()) {
            ContextThemeWrapper(
                context,
                com.google.android.material.R.style.Theme_Material3Expressive_DayNight_NoActionBar,
            )
        } else {
            context
        },
    )
    private val channel = MethodChannel(
        messenger,
        "roadway_native_navigation/navigation_bar/$viewId",
    )
    private var items = emptyList<NativeNavigationItem>()
    private var isUpdatingItems = false

    init {
        setItems(args)
        navigationView.setOnItemSelectedListener { menuItem ->
            if (!isUpdatingItems) {
                channel.invokeMethod("onItemSelected", menuItem.itemId)
            }
            true
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSelectedIndex" -> {
                    val index = (call.arguments as? Number)?.toInt()
                    if (index == null || index !in items.indices) {
                        result.error("invalid-selection", "The native navigation item index is invalid.", null)
                        return@setMethodCallHandler
                    }

                    if (navigationView.selectedItemId != index) {
                        navigationView.selectedItemId = index
                    }
                    result.success(null)
                }
                "setItems" -> {
                    try {
                        setItems(call.arguments)
                        result.success(null)
                    } catch (e: RuntimeException) {
                        result.error("invalid-items", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setItems(args: Any?) {
        val newItems = args.asNavigationItems(context)
        val selectedIndex = args.selectedIndex(newItems.size)

        isUpdatingItems = true
        try {
            navigationView.menu.clear()
            newItems.forEachIndexed { index, item ->
                navigationView.menu.add(0, index, index, item.label).icon = item.icon
            }
            navigationView.selectedItemId = selectedIndex
        } finally {
            isUpdatingItems = false
        }
        items = newItems
    }

    override fun getView(): View = navigationView

    override fun dispose() {
        channel.setMethodCallHandler(null)
    }
}

private data class NativeNavigationItem(val label: String, val icon: Drawable)

private enum class NativeNavigationIcon(val resourceId: Int) {
    HOME(R.drawable.roadway_native_navigation_ic_home),
    SEARCH(R.drawable.roadway_native_navigation_ic_search),
    FAVORITES(R.drawable.roadway_native_navigation_ic_favorites),
    PROFILE(R.drawable.roadway_native_navigation_ic_profile),
}

private fun Any?.asNavigationItems(context: Context): List<NativeNavigationItem> {
    val arguments = this as? Map<*, *> ?: error("Native navigation arguments are required.")
    val rawItems = arguments["items"] as? List<*> ?: error("Native navigation items are required.")
    check(rawItems.isNotEmpty() && rawItems.size <= 5) {
        "Native navigation requires between one and five items."
    }
    return rawItems.map { rawItem ->
        val item = rawItem as? Map<*, *> ?: error("A native navigation item is invalid.")
        val label = item["label"] as? String ?: error("A native navigation label is required.")
        NativeNavigationItem(label, item.asDrawable(context))
    }
}

private fun Map<*, *>.asDrawable(context: Context): Drawable {
    val iconBytes = this["iconBytes"] as? ByteArray
    if (iconBytes != null) {
        val bitmap = BitmapFactory.decodeByteArray(iconBytes, 0, iconBytes.size)
            ?: error("The native navigation image bytes are invalid.")
        return BitmapDrawable(context.resources, bitmap)
    }

    val iconName = this["icon"] as? String
        ?: error("A native navigation icon is required.")
    val resourceId = try {
        NativeNavigationIcon.valueOf(iconName.uppercase()).resourceId
    } catch (_: IllegalArgumentException) {
        error("The native navigation icon '$iconName' is unsupported.")
    }
    return requireNotNull(AppCompatResources.getDrawable(context, resourceId)) {
        "The native navigation icon resource is unavailable."
    }
}

private fun Any?.material3Expressive(): Boolean =
    (this as? Map<*, *>)?.get("material3Expressive") as? Boolean ?: false

private fun Any?.selectedIndex(itemCount: Int): Int {
    val arguments = this as? Map<*, *> ?: error("Native navigation arguments are required.")
    val selectedIndex = (arguments["selectedIndex"] as? Number)?.toInt()
        ?: error("The selected native navigation item is required.")
    check(selectedIndex in 0 until itemCount) {
        "The selected native navigation item index is invalid."
    }
    return selectedIndex
}
