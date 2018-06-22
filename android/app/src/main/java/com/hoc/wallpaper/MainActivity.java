package com.hoc.wallpaper;

import android.app.WallpaperManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import java.io.File;
import java.util.List;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "my_flutter_wallpaper";
    private static final String SET_WALLPAPER = "setWallpaper";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);


        new MethodChannel(getFlutterView(), CHANNEL)
                .setMethodCallHandler(new MethodChannel.MethodCallHandler() {
                    @Override
                    public void onMethodCall(MethodCall methodCall, MethodChannel.Result result) {
                        if (SET_WALLPAPER.equals(methodCall.method)) {
                            setWallpaper(methodCall.arguments, result);
                        } else {
                            result.notImplemented();
                        }
                    }
                });

        GeneratedPluginRegistrant.registerWith(this);
    }

    private void setWallpaper(Object args, MethodChannel.Result result) {
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
