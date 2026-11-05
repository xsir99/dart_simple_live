package com.xycz.simple_live_tv

import android.app.AlertDialog
import android.os.Bundle
import android.text.InputType
import android.widget.EditText
import android.widget.LinearLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.xycz.simple_live_tv/input"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showInputDialog" -> {
                    val title = call.argument<String>("title") ?: "输入"
                    val hint = call.argument<String>("hint") ?: ""
                    val initialText = call.argument<String>("initialText") ?: ""
                    showInputDialog(title, hint, initialText, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun showInputDialog(
        title: String,
        hint: String,
        initialText: String,
        result: MethodChannel.Result
    ) {
        runOnUiThread {
            val layout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(32, 32, 32, 32)
            }
            val editText = EditText(this).apply {
                setHint(hint)
                setText(initialText)
                inputType = InputType.TYPE_CLASS_TEXT or
                    InputType.TYPE_TEXT_FLAG_MULTI_LINE
                minLines = 4
                gravity = android.view.Gravity.TOP or android.view.Gravity.START
                isFocusable = true
                isFocusableInTouchMode = true
                requestFocus()
            }
            layout.addView(editText)

            val dialog = AlertDialog.Builder(this)
                .setTitle(title)
                .setView(layout)
                .setPositiveButton("保存") { _, _ ->
                    result.success(editText.text.toString())
                }
                .setNegativeButton("取消") { _, _ ->
                    result.error("CANCELLED", "用户取消", null)
                }
                .setOnCancelListener {
                    result.error("CANCELLED", "用户取消", null)
                }
                .create()

            dialog.setOnShowListener {
                editText.requestFocus()
                val imm = getSystemService(INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                imm.showSoftInput(editText, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT)
            }
            dialog.show()
        }
    }
}
