package com.hoc.wallpaper

import android.app.WallpaperManager
import android.graphics.Bitmap
import android.graphics.Bitmap.CompressFormat
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.drawable.Drawable
import android.media.MediaScannerConnection
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import com.facebook.CallbackManager.Factory
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
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
  private val mainHandler = Handler(Looper.getMainLooper())

  private val callback = object : FacebookCallback<Sharer.Result?> {
    override fun onSuccess(r: Sharer.Result?) {
      Toast.makeText(
        this@MainActivity,
        "Share image successfully",
        Toast.LENGTH_SHORT
      ).show()
    }

    override fun onCancel() {
      Toast.makeText(
        this@MainActivity,
        "Share cancelled",
        Toast.LENGTH_SHORT
      ).show()
    }

    override fun onError(error: FacebookException?) {
      Toast.makeText(
        this@MainActivity,
        "Error " + error?.message,
        Toast.LENGTH_SHORT
      ).show()
    }
  }

  private val target = object : Target {
    override fun onBitmapLoaded(bitmap: Bitmap?, from: LoadedFrom?) {
      Log.d("MY_TAG", "onBitmapLoaded")

      val photo = Builder()
        .setBitmap(bitmap)
        .build()

      val content = SharePhotoContent.Builder()
        .addPhoto(photo)
        .build()

      val shareDialog = ShareDialog(this@MainActivity)
        .apply { registerCallback(Factory.create(), callback) }

      if (shareDialog.canShow(content)) {
        Log.d("MY_TAG", "can show and show")
        shareDialog.show(content)
      } else {
        Log.d("MY_TAG", "can not show")
      }
    }

    override fun onBitmapFailed(
      e: Exception?,
      errorDrawable: Drawable?
    ) {
      Log.d("MY_TAG", "onBitmapFailed $e")
      Toast.makeText(
        this@MainActivity,
        "Loaded image failed",
        Toast.LENGTH_SHORT
      ).show()
    }

    override fun onPrepareLoad(placeHolderDrawable: Drawable?) {
      Log.d("MY_TAG", "onPrepareLoad")
    }
  }

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

  override fun onDestroy() {
    super.onDestroy()
    Picasso.get().cancelRequest(target)
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

    val byteArray = ByteArrayOutputStream()
      .also {
        getResizedBitmap(
          BitmapFactory.decodeByteArray(bytes, 0, bytes.size),
          width,
          height
        ).compress(CompressFormat.PNG, 100, it)
      }
      .toByteArray()

    result.success(byteArray)
  }

  private fun shareImageToFacebook(imageUrl: String?, result: Result) {
    if (imageUrl == null) {
      return result.error("error", "Imageurl cannot be null", null)
    }

    Log.d("MY_TAG", "imageUrl = $imageUrl")
    Picasso.get().load(imageUrl).into(target)
  }

  private fun scanImageFile(imagePath: List<Any>?, result: Result) {
    try {
      if (imagePath == null) {
        return result.error("error", "Arguments must be a list and not null", null)
      }

      if (!isExternalStorageReadable) {
        return result.error("error", "External storage is unavailable", null)
      }

      val absolutePath = getExternalFilesDir(null)!!.absolutePath
      val imageFilePath = absolutePath + File.separator + joinPath(imagePath)
      Log.d("MY_TAG", "Start scan: $imageFilePath")

      MediaScannerConnection.scanFile(
        this,
        arrayOf(imageFilePath),
        null
      ) { path, uri ->

        Log.d("MY_TAG", "Scan result Path: $path")
        Log.d("MY_TAG", "Scan result Uri: $uri")

        mainHandler.post { result.success("Scan completed") }
      }

    } catch (e: Exception) {
      result.error("error", e.message, null)
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
      val bitmap = BitmapFactory.decodeFile(imageFilePath)

      WallpaperManager.getInstance(this).setBitmap(bitmap)

      result.success("Set wallpaper successfully")
    } catch (e: Exception) {
      result.error("error", e.message, null)
    }
  }

  private companion object {
    const val CHANNEL = "my_flutter_wallpaper"
    const val SET_WALLPAPER = "setWallpaper"
    const val SCAN_FILE = "scanFile"
    const val SHARE_IMAGE_TO_FACEBOOK = "shareImageToFacebook"
    const val RESIZE_IMAGE = "resizeImage"
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