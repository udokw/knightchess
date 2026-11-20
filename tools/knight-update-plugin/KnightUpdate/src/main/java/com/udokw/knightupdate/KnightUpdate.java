package com.udokw.knightupdate;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;
import android.util.Log;
import android.view.View;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.util.HashSet;
import java.util.Set;

/**
 * 最小更新插件：DownloadManager 下载 APK + content:// 拉起系统安装器。
 * 检测与直链解析都在 GDScript（Update.gd）里完成，这里只负责安卓端的下载与安装。
 */
public class KnightUpdate extends GodotPlugin {
    private static final String TAG = "KnightUpdate";

    private Activity activity;
    private DownloadManager downloadManager;
    private long downloadId = -1L;
    private String pendingFileName = "";
    private boolean receiverRegistered = false;

    private final BroadcastReceiver downloadReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L);
            if (id != downloadId) {
                return;
            }
            handleDownloadComplete(context);
        }
    };

    public KnightUpdate(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "KnightUpdate";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("update_state", String.class, String.class));
        return signals;
    }

    @Override
    public View onMainCreate(Activity activity) {
        this.activity = activity;
        this.downloadManager = (DownloadManager) activity.getSystemService(Context.DOWNLOAD_SERVICE);
        registerReceiver();
        return null;
    }

    @Override
    public void onMainDestroy() {
        unregisterReceiver();
        this.activity = null;
    }

    /** GDScript 调用：下载并安装。url 为 feijipan 解析出的直链。 */
    @UsedByGodot
    public void downloadAndInstall(String url, String fileName) {
        Activity act = getActivity();
        if (act == null) {
            emit("error", "无法获取当前界面，请稍后重试。");
            return;
        }
        String name = sanitize(fileName);
        if (name.isEmpty()) {
            name = "knight_update.apk";
        }

        // 已经下载过：直接安装，避免重复下载
        File existing = new File(downloadDir(act), name);
        if (existing.isFile() && existing.length() > 0) {
            installApk(act, existing);
            return;
        }

        if (downloadManager == null) {
            downloadManager = (DownloadManager) act.getSystemService(Context.DOWNLOAD_SERVICE);
        }
        if (downloadManager == null) {
            emit("error", "系统下载服务不可用，请用浏览器打开下载。");
            return;
        }

        try {
            DownloadManager.Request req = new DownloadManager.Request(Uri.parse(url));
            req.setTitle(name);
            req.setDescription("骑士飞行棋更新包");
            req.setMimeType("application/vnd.android.package-archive");
            req.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            req.setDestinationInExternalFilesDir(act, Environment.DIRECTORY_DOWNLOADS, name);
            pendingFileName = name;
            downloadId = downloadManager.enqueue(req);
            registerReceiver();
            emit("downloading", "正在下载 " + name + "…");
        } catch (Exception e) {
            Log.e(TAG, "enqueue failed", e);
            emit("error", "下载启动失败：" + e.getMessage());
        }
    }

    private void handleDownloadComplete(Context context) {
        if (downloadManager == null) {
            return;
        }
        DownloadManager.Query query = new DownloadManager.Query();
        query.setFilterById(downloadId);
        try (android.database.Cursor cursor = downloadManager.query(query)) {
            if (cursor == null || !cursor.moveToFirst()) {
                emit("error", "下载结果查询失败。");
                return;
            }
            int status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
            if (status == DownloadManager.STATUS_SUCCESSFUL) {
                File file = new File(downloadDir(context), pendingFileName);
                if (file.isFile() && file.length() > 0) {
                    installApk(context, file);
                } else {
                    emit("error", "下载完成但文件不存在：" + pendingFileName);
                }
            } else if (status == DownloadManager.STATUS_FAILED) {
                int reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON));
                emit("error", "下载失败（原因码 " + reason + "），请稍后重试或用浏览器下载。");
            }
        } catch (Exception e) {
            Log.e(TAG, "query failed", e);
            emit("error", "下载完成但处理失败：" + e.getMessage());
        }
    }

    private void installApk(Context context, File file) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                && !context.getPackageManager().canRequestPackageInstalls()) {
            emit("permission", "下载完成。请允许本应用「安装未知应用」，然后再次点击「下载更新」继续安装。");
            openInstallPermissionSettings(context);
            return;
        }
        try {
            Uri uri = ApkProvider.uriFor(context, file);
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(uri, "application/vnd.android.package-archive");
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            context.startActivity(intent);
            emit("install", "已调起系统安装器，请按提示完成安装。");
        } catch (Exception e) {
            Log.e(TAG, "install failed", e);
            emit("error", "无法调起安装器：" + e.getMessage());
        }
    }

    private void openInstallPermissionSettings(Context context) {
        try {
            Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES);
            intent.setData(Uri.parse("package:" + context.getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            Log.e(TAG, "open settings failed", e);
        }
    }

    private void registerReceiver() {
        if (receiverRegistered || activity == null) {
            return;
        }
        IntentFilter filter = new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(downloadReceiver, filter, Context.RECEIVER_EXPORTED);
        } else {
            activity.registerReceiver(downloadReceiver, filter);
        }
        receiverRegistered = true;
    }

    private void unregisterReceiver() {
        if (!receiverRegistered || activity == null) {
            return;
        }
        try {
            activity.unregisterReceiver(downloadReceiver);
        } catch (Exception ignored) {
        }
        receiverRegistered = false;
    }

    private static File downloadDir(Context context) {
        File dir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS);
        if (dir == null) {
            dir = context.getFilesDir();
        }
        return dir;
    }

    private static String sanitize(String name) {
        if (name == null) {
            return "";
        }
        return name.replace('/', '_').replace('\\', '_').trim();
    }

    private void emit(String stage, String message) {
        try {
            emitSignal("update_state", stage, message);
        } catch (Exception e) {
            Log.e(TAG, "emitSignal failed", e);
        }
    }
}
