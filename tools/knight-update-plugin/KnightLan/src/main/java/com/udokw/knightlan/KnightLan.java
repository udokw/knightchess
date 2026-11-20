package com.udokw.knightlan;

import android.app.Activity;
import android.content.Context;
import android.net.wifi.WifiManager;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * 局域网发现所需的最小安卓插件。
 * 安卓 Wi-Fi 驱动默认过滤发往广播/组播地址的包，只有持有 MulticastLock
 * 才能收到房间通告（房主广播）与查询（客机广播）。
 */
public class KnightLan extends GodotPlugin {
    private static final String TAG = "KnightLan";

    private WifiManager.MulticastLock multicastLock;

    public KnightLan(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "KnightLan";
    }

    @UsedByGodot
    public void acquireMulticastLock() {
        Activity act = getActivity();
        if (act == null) {
            Log.w(TAG, "acquire ignored: no activity");
            return;
        }
        if (multicastLock == null) {
            WifiManager wifi = (WifiManager) act.getApplicationContext()
                    .getSystemService(Context.WIFI_SERVICE);
            if (wifi == null) {
                Log.w(TAG, "acquire ignored: no WifiManager");
                return;
            }
            multicastLock = wifi.createMulticastLock("knightchess-lan");
            multicastLock.setReferenceCounted(false);
        }
        if (!multicastLock.isHeld()) {
            multicastLock.acquire();
        }
        Log.i(TAG, "multicast lock held=" + multicastLock.isHeld());
    }

    @UsedByGodot
    public void releaseMulticastLock() {
        if (multicastLock != null && multicastLock.isHeld()) {
            multicastLock.release();
        }
        Log.i(TAG, "multicast lock released");
    }

    @UsedByGodot
    public boolean isMulticastLockHeld() {
        return multicastLock != null && multicastLock.isHeld();
    }
}
