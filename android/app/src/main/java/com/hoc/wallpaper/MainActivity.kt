package com.hoc.wallpaper

import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Bitmap.CompressFormat
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.drawable.Drawable
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import com.facebook.CallbackManager
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.share.Sharer
import com.facebook.share.model.SharePhoto.Builder
import com.facebook.share.model.SharePhotoContent
import com.facebook.share.widget.ShareDialog
import com.squareup.picasso.Picasso
import com.squareup.picasso.Picasso.LoadedFrom
import com.squareup.picasso.Target
import io.flutter.app.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

class MainActivity : FlutterActivity() {
  private val coroutineScope = MainScope()
  private val callbackManager = CallbackManager.Factory.create()

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    MethodChannel(flutterView, CHANNEL)
      .setMethodCallHandler { methodCall, result ->
        when (methodCall.method) {
          SET_WALLPAPER -> {
            setWallpaper(
              (methodCall.arguments as? List<*>)?.filterIsInstance<Any>(),
              result
            )
          }
          SCAN_FILE -> {
            scanImageFile(
              (methodCall.arguments as? List<*>)?.filterIsInstance<Any>(),
              result
            )
          }
          SHARE_IMAGE_TO_FACEBOOK -> {
            shareImageToFacebook(
              methodCall.arguments as? String,
              result
            )
          }
          RESIZE_IMAGE -> {
            resizeImage(
              result,
              methodCall.argument("bytes") as? ByteArray,
              methodCall.argument("width") as? Int,
              methodCall.argument("height") as? Int
            )
          }
          else -> result.notImplemented()
        }
      }

    GeneratedPluginRegistrant.registerWith(this)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    callbackManager.onActivityResult(requestCode, resultCode, data)
  }

  override fun onDestroy() {
    super.onDestroy()
    coroutineScope.cancel()
  }

  private fun resizeImage(
    result: Result,
    bytes: ByteArray?,
    width: Int?,
    height: Int?
  ) {
    if (width == null) {
      return result.error("error", "width cannot be null", null)
    }
    if (height == null) {
      return result.error("error", "height cannot be null", null)
    }
    if (bytes == null) {
      return result.error("error", "bytes cannot be null", null)
    }

    coroutineScope.launch {
      val byteArray = withContext(Dispatchers.IO) {
        ByteArrayOutputStream()
          .also {
            getResizedBitmap(
              BitmapFactory.decodeByteArray(bytes, 0, bytes.size),
              width,
              height
            ).compress(CompressFormat.PNG, 100, it)
          }
          .toByteArray()
      }
      result.success(byteArray)
    }
  }

  private fun shareImageToFacebook(imageUrl: String?, result: Result) {
    if (imageUrl == null) {
      return result.error("error", "imageUrl cannot be null", null)
    }

    Log.i(TAG, "imageUrl = $imageUrl")

    Picasso
      .get()
      .load(imageUrl)
      .into(object : Target {
        override fun onBitmapLoaded(bitmap: Bitmap?, from: LoadedFrom?) {
          Log.i(TAG, "onBitmapLoaded")

          val photo = Builder()
            .setBitmap(bitmap)
            .build()

          val content = SharePhotoContent.Builder()
            .addPhoto(photo)
            .build()

          val shareDialog = ShareDialog(this@MainActivity)
            .apply {
              registerCallback(
                callbackManager,
                object : FacebookCallback<Sharer.Result?> {
                  override fun onSuccess(r: Sharer.Result?) {
                    Toast.makeText(
                      this@MainActivity.applicationContext,
                      "Share image successfully",
                      Toast.LENGTH_SHORT
                    ).show()

                    Log.i(TAG, "Share image successfully")
                  }

                  override fun onCancel() {
                    Toast.makeText(
                      this@MainActivity.applicationContext,
                      "Share cancelled",
                      Toast.LENGTH_SHORT
                    ).show()

                    Log.i(TAG, "Share cancelled")
                  }

                  override fun onError(error: FacebookException?) {
                    Toast.makeText(
                      this@MainActivity.applicationContext,
                      "Error ${error?.message}",
                      Toast.LENGTH_SHORT
                    ).show()

                    Log.i(TAG, "Error ${error?.message}")
                  }
                }
              )
            }

          if (shareDialog.canShow(content)) {
            shareDialog.show(content)

            Log.i(TAG, "can show and show")
            result.success(null)
          } else {
            Log.i(TAG, "can not show")
            result.error("error", "Cannot show share dialog", null)
          }
        }

        override fun onBitmapFailed(e: Exception?, errorDrawable: Drawable?) {
          Log.i(TAG, "onBitmapFailed $e")

          Toast.makeText(
            this@MainActivity,
            "Loaded image failed",
            Toast.LENGTH_SHORT
          ).show()

          result.error("error", "Loaded image failed", null)
        }

        override fun onPrepareLoad(placeHolderDrawable: Drawable?) {
          Log.i(TAG, "onPrepareLoad")
        }
      })
  }

  private fun scanImageFile(imagePath: List<Any>?, result: Result) {
    if (imagePath == null) {
      return result.error("error", "Arguments must be a list and not null", null)
    }

    if (!isExternalStorageReadable) {
      return result.error("error", "External storage is unavailable", null)
    }

    val absolutePath = getExternalFilesDir(null)!!.absolutePath
    val imageFilePath = absolutePath + File.separator + joinPath(imagePath)
    Log.i(TAG, "Start scan: $imageFilePath")

    coroutineScope.launch {
      try {
        val (path, uri) = withContext(Dispatchers.IO) { scanFile(imageFilePath) }

        Log.i(TAG, "Scan result Path: $path")
        Log.i(TAG, "Scan result Uri: $uri")

        result.success("Scan completed")
      } catch (e: Exception) {
        Log.i(TAG, "Scan file error: $e")
        result.error("error", e.message, null)
      }
    }
  }

  private fun setWallpaper(path: List<Any>?, result: Result) {
    try {
      if (path == null) {
        return result.error("error", "Arguments must be a list and not null", null)
      }

      if (!isExternalStorageReadable) {
        return result.error("error", "External storage is unavailable", null)
      }

      val absolutePath = getExternalFilesDir(null)!!.absolutePath
      val imageFilePath = absolutePath + File.separator + joinPath(path)

      coroutineScope.launch {
        withContext(Dispatchers.IO) {
          val bitmap = BitmapFactory.decodeFile(imageFilePath)
          WallpaperManager.getInstance(this@MainActivity).setBitmap(bitmap)
        }
        result.success("Set wallpaper successfully")
      }

    } catch (e: Exception) {
      result.error("error", e.message, null)
    }
  }

  companion object {
    const val CHANNEL = "my_flutter_wallpaper"
    const val SET_WALLPAPER = "setWallpaper"
    const val SCAN_FILE = "scanFile"
    const val SHARE_IMAGE_TO_FACEBOOK = "shareImageToFacebook"
    const val RESIZE_IMAGE = "resizeImage"
    const val TAG = "flutter"
  }
}

private fun getResizedBitmap(
  bm: Bitmap,
  newWidth: Int,
  newHeight: Int
): Bitmap {
  val width = bm.width
  val height = bm.height

  val scaleWidth = newWidth.toFloat() / width
  val scaleHeight = newHeight.toFloat() / height

  val matrix = Matrix().apply { postScale(scaleWidth, scaleHeight) }
  return Bitmap.createBitmap(bm, 0, 0, width, height, matrix, false)
}


private fun joinPath(path: List<Any>) = path.joinToString(separator = File.separator)

/**
 * Checks if external storage is available to at least read
 */
private val isExternalStorageReadable
  get() = Environment.getExternalStorageState().let { state ->
    Environment.MEDIA_MOUNTED == state || Environment.MEDIA_MOUNTED_READ_ONLY == state
  }


private suspend fun Context.scanFile(imageFilePath: String): Pair<String?, Uri?> {
  return suspendCoroutine { continuation ->
    MediaScannerConnection.scanFile(
      this,
      arrayOf(imageFilePath),
      null
    ) { path, uri ->
      continuation.resume(path to uri)
    }
  }
}