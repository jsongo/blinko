package com.blinko.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsetsController
import androidx.core.view.WindowCompat
import org.json.JSONObject
import com.plugin.blinko.Blinko

class MainActivity : TauriActivity() {
    private var hasInjectedShortcut = false
    private var hasInjectedShare = false
    private val blinko = Blinko()

    override fun onCreate(savedInstanceState: Bundle?) {
        // Apply saved theme before super.onCreate to prevent flash
        blinko.applyStartupTheme(this)
        super.onCreate(savedInstanceState)

        // Enable edge-to-edge mode
        setupEdgeToEdge()

        enableWebViewBounceEffect()
        handleShortcutIntent()
        handleShareIntent()
    }

    private fun setupEdgeToEdge() {
        // Let content draw behind system bars
        WindowCompat.setDecorFitsSystemWindows(window, false)

        window.apply {
            // Set status bar and navigation bar to transparent
            statusBarColor = android.graphics.Color.TRANSPARENT
            navigationBarColor = android.graphics.Color.TRANSPARENT

            // For Android 11 (API 30) and above, use WindowInsetsController
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                insetsController?.let { controller ->
                    // This will be controlled by theme (light/dark mode)
                    // The theme XML already sets windowLightStatusBar
                }
            } else {
                // For older Android versions, use deprecated API
                @Suppress("DEPRECATION")
                decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Reset flags for new intent
        hasInjectedShortcut = false
        hasInjectedShare = false
        handleShortcutIntent()
        handleShareIntent()
    }

    private fun enableWebViewBounceEffect() {
        // Use a small delay to ensure WebView is initialized
        window.decorView.postDelayed({
            try {
                findWebView(window.decorView)?.let { webView ->
                    // Enable bounce/overscroll effect
                    webView.overScrollMode = View.OVER_SCROLL_ALWAYS
                    Log.i("BlinkoApp", "WebView bounce effect enabled")
                }
            } catch (e: Exception) {
                Log.e("BlinkoApp", "Failed to enable WebView bounce effect: ${e.message}")
            }
        }, 500L) // Short delay to ensure WebView is ready
    }

    private fun handleShortcutIntent() {
        if (hasInjectedShortcut) return

        intent?.data?.let { uri ->
            if (uri.scheme == "blinko" && uri.host == "shortcut") {
                uri.pathSegments?.firstOrNull()?.let { action ->
                    hasInjectedShortcut = true
                    // Single injection with reasonable delay for WebView to be ready
                    window.decorView.postDelayed({
                        injectShortcutAction(action)
                    }, 1500L)
                }
            }
        }
    }
    
    private fun injectShortcutAction(action: String) {
        try {
            findWebView(window.decorView)?.evaluateJavascript(
                """
                (function() {
                    var key = 'android_shortcut_action';
                    var existing = window.localStorage.getItem(key);
                    if (!existing || existing === 'null' || existing === '') {
                        window.localStorage.setItem(key, '$action');
                        console.log('Injected shortcut action: $action');
                    } else {
                        console.log('Shortcut action already exists: ' + existing);
                    }
                })();
                """.trimIndent(), null
            )
        } catch (e: Exception) {
            // Silently ignore
        }
    }
    
    private fun findWebView(view: View): android.webkit.WebView? {
        if (view is android.webkit.WebView) return view
        if (view is android.view.ViewGroup) {
            for (i in 0 until view.childCount) {
                findWebView(view.getChildAt(i))?.let { return it }
            }
        }
        return null
    }

    private fun handleShareIntent() {
        if (hasInjectedShare) return

        if (intent?.action == Intent.ACTION_SEND) {
            hasInjectedShare = true
            val payload = intentToJson(intent)
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uri ->
                val name = getNameFromUri(uri)
                if (name != null && name != "") {
                    payload.put("name", name)
                    Log.i("got name", name)
                }
            }
            Log.i("triggering event", payload.toString())

            // Single injection with reasonable delay for WebView to be ready
            window.decorView.postDelayed({
                injectShareData(payload.toString())
            }, 1500L)
        }
    }

    private fun intentToJson(intent: Intent): JSONObject {
        val json = JSONObject()
        Log.i("processing", intent.toUri(0))
        json.put("uri", intent.toUri(0))
        json.put("content_type", intent.type)

        // Get text content
        intent.getStringExtra(Intent.EXTRA_TEXT)?.let { text ->
            // Remove surrounding quotes if present
            val cleanedText = text.trim().let { trimmed ->
                when {
                    trimmed.startsWith("\"") && trimmed.endsWith("\"") -> trimmed.substring(1, trimmed.length - 1)
                    trimmed.startsWith("'") && trimmed.endsWith("'") -> trimmed.substring(1, trimmed.length - 1)
                    trimmed.startsWith("`") && trimmed.endsWith("`") -> trimmed.substring(1, trimmed.length - 1)
                    else -> trimmed
                }
            }
            json.put("text", cleanedText)
        }

        // Get subject
        intent.getStringExtra(Intent.EXTRA_SUBJECT)?.let {
            json.put("subject", it)
        }

        val streamUrl = intent.extras?.get("android.intent.extra.STREAM")
        if (streamUrl != null) {
            json.put("stream", streamUrl)
        }
        return json
    }

    private fun getNameFromUri(uri: Uri): String? {
        var displayName: String? = ""
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        val cursor = contentResolver.query(uri, projection, null, null, null)
        if (cursor != null) {
            cursor.moveToFirst()
            val columnIdx = cursor.getColumnIndex(projection[0])
            displayName = cursor.getString(columnIdx)
            cursor.close()
        }
        if (displayName.isNullOrEmpty()) {
            displayName = uri.lastPathSegment
        }
        return displayName
    }

    private fun injectShareData(shareData: String) {
        try {
            val escapedData = shareData.replace("\\", "\\\\").replace("\"", "\\\"").replace("'", "\\'")
            findWebView(window.decorView)?.evaluateJavascript(
                """
                (function() {
                    var key = 'android_share_data';
                    var existing = window.localStorage.getItem(key);
                    if (!existing || existing === 'null' || existing === '') {
                        window.localStorage.setItem(key, '$escapedData');
                        console.log('Injected share data');
                    } else {
                        console.log('Share data already exists');
                    }
                })();
                """.trimIndent(), null
            )
        } catch (e: Exception) {
            // Silently ignore
        }
    }


}