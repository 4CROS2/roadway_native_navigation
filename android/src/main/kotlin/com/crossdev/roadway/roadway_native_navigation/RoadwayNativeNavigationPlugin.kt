package com.crossdev.roadway.roadway_native_navigation

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.view.View
import androidx.appcompat.content.res.AppCompatResources
import com.google.android.material.bottomnavigation.BottomNavigationView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

class RoadwayNativeNavigationPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            NativeNavigationBarFactory(binding.binaryMessenger),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit

    private companion object {
        const val VIEW_TYPE = "roadway_native_navigation/navigation_bar"
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
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    args: Any?,
) : PlatformView {
    private val navigationView = BottomNavigationView(context)
    private val channel = MethodChannel(
        messenger,
        "roadway_native_navigation/navigation_bar/$viewId",
    )
    private val items = args.asNavigationItems(context)

    init {
        val selectedIndex = args.selectedIndex(items.size)
        items.forEachIndexed { index, item ->
            navigationView.menu.add(0, index, index, item.label).icon = item.icon
        }
        navigationView.selectedItemId = selectedIndex
        navigationView.setOnItemSelectedListener { menuItem ->
            channel.invokeMethod("onItemSelected", menuItem.itemId)
            true
        }
        channel.setMethodCallHandler { call, result ->
            if (call.method != "setSelectedIndex") {
                result.notImplemented()
                return@setMethodCallHandler
            }

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

private fun Any?.selectedIndex(itemCount: Int): Int {
    val arguments = this as? Map<*, *> ?: error("Native navigation arguments are required.")
    val selectedIndex = (arguments["selectedIndex"] as? Number)?.toInt()
        ?: error("The selected native navigation item is required.")
    check(selectedIndex in 0 until itemCount) {
        "The selected native navigation item index is invalid."
    }
    return selectedIndex
}
