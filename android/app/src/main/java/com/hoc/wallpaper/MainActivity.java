package com.hoc.wallpaper;

import android.app.WallpaperManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import android.widget.Toast;

import com.facebook.CallbackManager;
import com.facebook.FacebookCallback;
import com.facebook.FacebookException;
import com.facebook.share.Sharer;
import com.facebook.share.model.SharePhoto;
import com.facebook.share.model.SharePhotoContent;
import com.facebook.share.widget.ShareDialog;

import java.io.File;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.List;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import static io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import static io.flutter.plugin.common.MethodChannel.Result;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "my_flutter_wallpaper";
    private static final String SET_WALLPAPER = "setWallpaper";
    private static final String SCAN_FILE = "scanFile";
    private static final String SHARE_IMAGE_TO_FACEBOOK = "shareImageToFacebook";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        new MethodChannel(getFlutterView(), CHANNEL)
                .setMethodCallHandler(new MethodCallHandler() {
                    @Override
                    public void onMethodCall(MethodCall methodCall, Result result) {
                        switch (methodCall.method) {
                            case SET_WALLPAPER:
                                setWallpaper(methodCall.arguments, result);
                                break;
                            case SCAN_FILE:
                                scanImageFile(methodCall.arguments, result);
                                break;
                            case SHARE_IMAGE_TO_FACEBOOK:
                                shareImageToFacebook((String) methodCall.arguments);
                                break;
                            default:
                                result.notImplemented();
                                break;
                        }
                    }
                });

        GeneratedPluginRegistrant.registerWith(this);
    }

    private void shareImageToFacebook(String imageUrl) {
        Bitmap image;
        try {
            image = getBitmapFromURL(imageUrl);
        } catch (Exception e) {
            e.printStackTrace();
            Toast.makeText(this,"Error "+ e.getMessage(), Toast.LENGTH_SHORT).show();
            return;
        }
        if (image == null) {
            Toast.makeText(this, "An error occurred", Toast.LENGTH_SHORT).show();
            return;
        }
        SharePhoto photo = new SharePhoto.Builder()
                .setBitmap(image)
                .build();
        SharePhotoContent content = new SharePhotoContent.Builder()
                .addPhoto(photo)
                .build();

        ShareDialog shareDialog = new ShareDialog(this);
        shareDialog.registerCallback(CallbackManager.Factory.create(), new FacebookCallback<Sharer.Result>() {
            @Override
            public void onSuccess(Sharer.Result result) {
                Toast.makeText(MainActivity.this, "Share image successfully", Toast.LENGTH_SHORT).show();
            }

            @Override
            public void onCancel() {
                Toast.makeText(MainActivity.this, "Share cancelled", Toast.LENGTH_SHORT).show();
            }

            @Override
            public void onError(FacebookException error) {
                Toast.makeText(MainActivity.this, "Error " + error.getMessage(), Toast.LENGTH_SHORT).show();
            }
        });
        if (shareDialog.canShow(content)) {
            shareDialog.show(content);
        }
    }

    public static Bitmap getBitmapFromURL(String src) throws Exception {
        URL url = new URL(src);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setDoInput(true);
        connection.connect();
        return BitmapFactory.decodeStream(connection.getInputStream());
    }

    private void scanImageFile(Object args, final Result result) {
        try {
            if (!(args instanceof List)) {
                result.error("error", "Arguments must be a list", null);
                return;
            }
            final List path = (List) args;

            if (!isExternalStorageReadable()) {
                result.error("error", "External storage is unavailable", null);
                return;
            }

            final String absolutePath = Environment.getExternalStorageDirectory().getAbsolutePath();
            final String imageFilePath = absolutePath + File.separator + joinPath(path);


            MediaScannerConnection.scanFile(this, new String[]{imageFilePath},
                    null,
                    new MediaScannerConnection.OnScanCompletedListener() {
                        @Override
                        public void onScanCompleted(String path, Uri uri) {
                            Log.d("MY_TAG", "Path: " + path);
                            Log.d("MY_TAG", "Uri: " + uri);
                            result.success("Scan completed");
                        }
                    });
        } catch (Exception e) {
            result.error("error", e.getMessage(), null);
        }
    }

    private void setWallpaper(Object args, Result result) {
        try {
            if (!(args instanceof List)) {
                result.error("error", "Arguments must be a list", null);
                return;
            }
            final List path = (List) args;

            if (!isExternalStorageReadable()) {
                result.error("error", "External storage is unavailable", null);
                return;
            }

            final String absolutePath = Environment.getExternalStorageDirectory().getAbsolutePath();
            final String imageFilePath = absolutePath + File.separator + joinPath(path);
            final Bitmap bitmap = BitmapFactory.decodeFile(imageFilePath);

            final WallpaperManager wallpaperManager = WallpaperManager.getInstance(this);
            wallpaperManager.setBitmap(bitmap);

            result.success("Set wallpaper successfully");
        } catch (Exception e) {
            result.error("error", e.getMessage(), null);
        }
    }

    private String joinPath(List path) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < path.size(); i++) {
            sb.append(path.get(i));
            if (i < path.size() - 1) {
                sb.append(File.separator);
            }
        }
        return sb.toString();
    }

    /* Checks if external storage is available to at least read */
    private boolean isExternalStorageReadable() {
        final String state = Environment.getExternalStorageState();
        return Environment.MEDIA_MOUNTED.equals(state) || Environment.MEDIA_MOUNTED_READ_ONLY.equals(state);
    }
}
