# Implementation Guide: Fix Mozilla VPN Battery Optimization Issue

## Quick Summary
Mozilla VPN doesn't handle Android battery optimization, causing the VPN to disconnect after a few hours or fail to restart after device reboot. This guide shows how to fix it using proven patterns from Threema.

---

## Step 1: Add Battery Optimization Permission

### File: `mozilla-vpn-client/android/AndroidManifest.xml`

Add this permission (after line 14):
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>  <!-- ADD THIS -->
<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
```

**Why?** This allows the app to request battery optimization exemption directly via system dialog.

---

## Step 2: Create Battery Optimization Helper

### File: `mozilla-vpn-client/android/common/src/main/java/org/mozilla/firefox/qt/common/BatteryOptimizationHelper.kt`

Create new file:
```kotlin
package org.mozilla.firefox.qt.common

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.RequiresApi

object BatteryOptimizationHelper {
    private const val TAG = "BatteryOptimizationHelper"

    /**
     * Check if battery optimizations are disabled for this app.
     * Returns true if optimizations are disabled (good for VPN).
     * Returns true if check fails (assume it's okay).
     */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            // Battery optimization was introduced in Android M
            return true
        }

        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check battery optimization status", e)
            // Assume it's okay if we can't check
            true
        }
    }

    /**
     * Check if we have permission to request battery optimization exemption.
     */
    fun hasRequestIgnoreBatteryOptimizationsPermission(context: Context): Boolean {
        return try {
            val permission = "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"
            context.packageManager.checkPermission(permission, context.packageName) == 
                PackageManager.PERMISSION_GRANTED
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Get intent to request battery optimization exemption.
     * Returns null if the intent cannot be created.
     */
    @RequiresApi(Build.VERSION_CODES.M)
    fun getRequestIgnoreBatteryOptimizationsIntent(context: Context): Intent? {
        return try {
            if (hasRequestIgnoreBatteryOptimizationsPermission(context)) {
                // Can request directly via system dialog
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:${context.packageName}")
                intent
            } else {
                // Need to guide user to settings manually
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+: Go to app details
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:${context.packageName}")
                    }
                } else {
                    // Android 6-11: Go to battery optimization list
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create battery optimization intent", e)
            null
        }
    }

    /**
     * Check if background restrictions are enabled for this app.
     * Returns true if restrictions are enabled (bad for VPN).
     */
    @RequiresApi(Build.VERSION_CODES.P)
    fun isBackgroundRestricted(context: Context): Boolean {
        return try {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            activityManager.isBackgroundRestricted()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check background restrictions", e)
            false
        }
    }
}
```

---

## Step 3: Add Battery Status Check to VPNService

### File: `mozilla-vpn-client/android/daemon/src/main/java/org/mozilla/firefox/vpn/daemon/VPNService.kt`

Add check in `onCreate()` (after line 85):
```kotlin
override fun onCreate() {
    super.onCreate()
    Log.init(this)
    Log.i(tag, "Creating the service")
    
    // Check battery optimization status and log warning
    checkBatteryOptimizationStatus()  // ADD THIS
    
    currentTunnelHandle = -1
    // ... rest of onCreate
}

// ADD THIS METHOD
private fun checkBatteryOptimizationStatus() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val isIgnoring = BatteryOptimizationHelper.isIgnoringBatteryOptimizations(this)
        if (!isIgnoring) {
            Log.w(tag, "⚠️ Battery optimization is ENABLED - VPN may disconnect after a few hours!")
            Log.w(tag, "⚠️ User should disable battery optimization for reliable VPN operation")
            
            // Send broadcast to notify UI (if it's running)
            val intent = Intent("org.mozilla.firefox.vpn.BATTERY_OPTIMIZATION_WARNING")
            sendBroadcast(intent)
        } else {
            Log.i(tag, "✓ Battery optimization is disabled - VPN should remain stable")
        }
        
        // Check background restrictions on Android P+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            if (BatteryOptimizationHelper.isBackgroundRestricted(this)) {
                Log.w(tag, "⚠️ Background restrictions are enabled - VPN may not work properly!")
            }
        }
    }
}
```

---

## Step 4: Add Warning UI to Main Activity

### File: `mozilla-vpn-client/android/vpnClient/src/main/java/org/mozilla/firefox/vpn/qt/VPNActivity.java`

Add battery optimization check and warning (this is simplified - you'll need to integrate with your existing UI):

```java
import org.mozilla.firefox.qt.common.BatteryOptimizationHelper;

public class VPNActivity extends QtActivity {
    
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Check battery optimization after activity is created
        checkAndWarnBatteryOptimization();
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        
        // Check again when returning to app
        checkAndWarnBatteryOptimization();
    }
    
    private void checkAndWarnBatteryOptimization() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return;
        }
        
        if (!BatteryOptimizationHelper.isIgnoringBatteryOptimizations(this)) {
            // Show warning to user
            showBatteryOptimizationWarning();
        }
    }
    
    private void showBatteryOptimizationWarning() {
        new AlertDialog.Builder(this)
            .setTitle("Battery Optimization Detected")
            .setMessage("Mozilla VPN may disconnect after a few hours because battery optimization is enabled.\n\n" +
                       "For reliable VPN operation, please disable battery optimization for Mozilla VPN.\n\n" +
                       "Would you like to open settings now?")
            .setPositiveButton("Open Settings", (dialog, which) -> {
                Intent intent = BatteryOptimizationHelper.getRequestIgnoreBatteryOptimizationsIntent(this);
                if (intent != null) {
                    try {
                        startActivity(intent);
                    } catch (Exception e) {
                        Log.e("VPNActivity", "Failed to open battery settings", e);
                    }
                }
            })
            .setNegativeButton("Not Now", null)
            .setNeutralButton("Don't Ask Again", (dialog, which) -> {
                // Save preference to not ask again
                getSharedPreferences("vpn_prefs", MODE_PRIVATE)
                    .edit()
                    .putBoolean("battery_optimization_warning_dismissed", true)
                    .apply();
            })
            .show();
    }
}
```

---

## Step 5: Improve Boot Receiver

### File: `mozilla-vpn-client/android/daemon/src/main/java/org/mozilla/firefox/vpn/daemon/BootReceiver.kt`

Improve error handling:
```kotlin
class BootReceiver : BroadcastReceiver() {
    private val TAG = "BootReceiver"

    override fun onReceive(context: Context, arg1: Intent) {
        Log.init(context)
        
        if (!Prefs.get(context).getBoolean(START_ON_BOOT, false)) {
            Log.i(TAG, "Start on boot is disabled - exit")
            return
        }
        
        // Check battery optimization status
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val isIgnoring = BatteryOptimizationHelper.isIgnoringBatteryOptimizations(context)
            if (!isIgnoring) {
                Log.w(TAG, "⚠️ Battery optimization is enabled - VPN may not start from background!")
                Log.w(TAG, "⚠️ This is why VPN may not restart after reboot")
                
                // Still try to start, but it might fail on Android 12+
            } else {
                Log.i(TAG, "✓ Battery optimization is disabled - safe to start VPN")
            }
        }
        
        Log.i(TAG, "Device rebooted - attempting to start VPN service")
        val intent = Intent(context, VPNService::class.java)
        intent.putExtra("startOnBoot", true)
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
                Log.i(TAG, "✓ Successfully queued VPN service start")
            } else {
                context.startService(intent)
                Log.i(TAG, "✓ Successfully started VPN service")
            }
        } catch (e: IllegalStateException) {
            // This exception happens on Android 12+ when battery optimization is enabled
            Log.e(TAG, "❌ Failed to start VPN service from background!")
            Log.e(TAG, "❌ This is likely because battery optimization is enabled")
            Log.e(TAG, "❌ User needs to disable battery optimization for auto-restart to work")
            Log.e(TAG, "Exception: ${e.message}")
            
            // Create a notification to inform user
            showFailedToStartNotification(context)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Unexpected error starting VPN service", e)
        }
    }
    
    private fun showFailedToStartNotification(context: Context) {
        // TODO: Implement notification showing VPN failed to auto-start
        // and guide user to disable battery optimization
    }
}
```

---

## Step 6: Add Persistent Notification (Optional but Recommended)

When VPN is running, show a notification that explains why battery optimization should be disabled:

```kotlin
private fun createVPNNotification(context: Context): Notification {
    val channelId = "vpn_service_channel"
    
    // Create notification channel (Android O+)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            channelId,
            "VPN Service",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows when VPN is active"
        }
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }
    
    // Check battery optimization status to customize message
    val batteryOptimized = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        !BatteryOptimizationHelper.isIgnoringBatteryOptimizations(context)
    } else {
        false
    }
    
    val contentText = if (batteryOptimized) {
        "VPN Active - ⚠️ Battery optimization enabled (may disconnect)"
    } else {
        "VPN Active - Protected"
    }
    
    return NotificationCompat.Builder(context, channelId)
        .setContentTitle("Mozilla VPN")
        .setContentText(contentText)
        .setSmallIcon(R.drawable.ic_notification)  // Use your VPN icon
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setOngoing(true)
        .build()
}
```

---

## Testing Steps

### Test 1: Battery Optimization Detection
1. Build and install modified APK
2. Launch Mozilla VPN
3. **Expected**: Warning dialog appears about battery optimization
4. Click "Open Settings"
5. **Expected**: Opens battery settings for Mozilla VPN
6. Change to "Unrestricted"
7. Return to app
8. **Expected**: No warning appears

### Test 2: VPN Stability
1. Set battery optimization to "Optimized" (default)
2. Start VPN
3. Wait 2-4 hours
4. **Before fix**: VPN disconnects
5. **After fix**: Warning was shown to user
6. Disable battery optimization
7. Start VPN again
8. Wait 24+ hours
9. **Expected**: VPN stays connected

### Test 3: Boot Restart
1. Ensure battery optimization is "Unrestricted"
2. Enable "Start on Boot" in VPN settings
3. Start VPN
4. Restart device
5. Check VPN status after boot
6. **Expected**: VPN automatically reconnects

### Test 4: Boot Restart with Optimization Enabled (Negative Test)
1. Set battery optimization to "Optimized"
2. Enable "Start on Boot" in VPN settings
3. Start VPN
4. Restart device
5. Check VPN status after boot
6. **Expected**: VPN does NOT start (and logs explain why)
7. Open app
8. **Expected**: Warning dialog explains battery optimization issue

---

## Monitoring & Telemetry (Optional)

Add telemetry to track the issue:

```kotlin
object VPNTelemetry {
    fun reportBatteryOptimizationStatus(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val isIgnoring = BatteryOptimizationHelper.isIgnoringBatteryOptimizations(context)
            
            // Send to your analytics service
            Analytics.record("vpn.battery_optimization", mapOf(
                "is_ignoring" to isIgnoring,
                "android_version" to Build.VERSION.SDK_INT
            ))
        }
    }
    
    fun reportUnexpectedDisconnection(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val isIgnoring = BatteryOptimizationHelper.isIgnoringBatteryOptimizations(context)
            
            Analytics.record("vpn.unexpected_disconnect", mapOf(
                "battery_optimization_enabled" to !isIgnoring
            ))
        }
    }
}
```

---

## Summary of Changes

### New Files:
1. `mozilla-vpn-client/android/common/src/main/java/org/mozilla/firefox/qt/common/BatteryOptimizationHelper.kt`

### Modified Files:
1. `mozilla-vpn-client/android/AndroidManifest.xml` - Add permission
2. `mozilla-vpn-client/android/daemon/src/main/java/org/mozilla/firefox/vpn/daemon/VPNService.kt` - Add check
3. `mozilla-vpn-client/android/daemon/src/main/java/org/mozilla/firefox/vpn/daemon/BootReceiver.kt` - Improve logging
4. `mozilla-vpn-client/android/vpnClient/src/main/java/org/mozilla/firefox/vpn/qt/VPNActivity.java` - Add warning UI

### Lines of Code:
- **New code**: ~200 lines
- **Modified code**: ~50 lines
- **Total effort**: ~2-4 hours for experienced Android developer

---

## Expected Outcome

After implementing these changes:

1. ✅ Users will be warned about battery optimization
2. ✅ Users can easily disable it with one click
3. ✅ VPN will survive 24+ hours without disconnection
4. ✅ VPN will restart after device reboot
5. ✅ Better logging helps troubleshoot issues
6. ✅ Users understand why the setting is important

---

## References

- **Issue**: https://github.com/mozilla-mobile/mozilla-vpn-client/issues/10702
- **Threema Implementation**: `threema-android/app/src/main/java/ch/threema/app/utils/PowermanagerUtil.java`
- **Android Docs**: https://developer.android.com/training/monitoring-device-state/doze-standby

