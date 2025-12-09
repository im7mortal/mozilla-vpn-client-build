# Analysis: Why Threema-libre Survives Restarts but Mozilla VPN Doesn't

## Summary
Threema-libre actively manages battery optimization settings and proactively warns users, while Mozilla VPN does not handle battery optimization at all, causing Android to kill the VPN service.

---

## Key Differences

### 1. Battery Optimization Permission

**Threema-libre:**
- ✅ **Has** `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission in `app/src/libre/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

**Mozilla VPN:**
- ❌ **Does NOT have** this permission in any manifest file
- No battery optimization handling code anywhere in the codebase

---

### 2. Battery Optimization Detection & User Warning

**Threema-libre:**

#### PowermanagerUtil.java
Checks if battery optimizations are disabled:
```java
public static boolean isIgnoringBatteryOptimizations(@NonNull Context context) {
    final PowerManager powerManager = (PowerManager) context.getApplicationContext()
        .getSystemService(POWER_SERVICE);
    return powerManager.isIgnoringBatteryOptimizations(context.getPackageName());
}
```

#### ProblemSolverActivity.kt
Actively warns users when battery optimization is enabled:
```kotlin
Problem(
    title = R.string.problemsolver_title_app_battery_usgae_optimized,
    explanation = getString(R.string.problemsolver_explain_app_battery_usgae_optimized),
    intentAction = Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
    check = ThreemaApplication.getServiceManager()?.preferenceService?.useThreemaPush() ?: false &&
        !PowermanagerUtil.isIgnoringBatteryOptimizations(this),
)
```

#### DisableBatteryOptimizationsActivity.java
Guides users through disabling battery optimization with:
- Direct system settings intent
- Toast messages to guide users
- Fallback for different Android versions

**Mozilla VPN:**
- ❌ **No battery optimization detection**
- ❌ **No user warnings**
- ❌ **No UI to help users disable it**

---

### 3. Boot Receiver Implementation

**Both apps have boot receivers, but with different robustness:**

#### Threema-libre: `AutoStartNotifyReceiver.kt`
```kotlin
class AutoStartNotifyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            logger.info("*** Phone rebooted - AutoStart")
            val workRequest = OneTimeWorkRequest.Builder(AutostartWorker::class.java)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context)
                .enqueueUniqueWork(WorkerNames.WORKER_AUTOSTART, ExistingWorkPolicy.REPLACE, workRequest)
        }
    }
}
```
- Uses **WorkManager** for reliable background execution
- Has **exponential backoff** for retry logic
- More resilient to battery optimization

#### Mozilla VPN: `BootReceiver.kt`
```kotlin
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, arg1: Intent) {
        if (!Prefs.get(context).getBoolean(START_ON_BOOT, false)) {
            return
        }
        val intent = Intent(context, VPNService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        }
    }
}
```
- Directly starts foreground service
- **Will fail if battery optimization is enabled** because Android won't let it start the service from background on API 31+

---

### 4. Foreground Service Management

**Threema-libre: `ThreemaPushService.kt`**
```kotlin
class ThreemaPushService : Service() {
    override fun onCreate() {
        // Start foreground IMMEDIATELY with notification
        ServiceCompat.startForeground(
            this,
            THREEMA_PUSH_ACTIVE_NOTIFICATION_ID,
            builder.build(),
            FG_SERVICE_TYPE,
        )
        
        // Acquire unpauseable connection
        lifetimeService.acquireUnpauseableConnection(LIFETIME_SERVICE_TAG)
    }
}
```
- Starts foreground service with notification **immediately**
- Uses `FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING` on Android 14+
- Has explicit connection lifetime management
- Handles `ForegroundServiceStartNotAllowedException` on Android 12+

**Mozilla VPN: `VPNService.kt`**
- Uses standard VPN service
- Has `systemExempted` foreground service type
- **BUT** can still be killed by battery optimization because it doesn't check/request exemption

---

### 5. Proactive Problem Detection

**Threema-libre has comprehensive checks:**
```kotlin
private val problems by lazy {
    arrayOf(
        Problem(title = R.string.problemsolver_title_background,
                check = ConfigUtils.isBackgroundRestricted(this)),
        Problem(title = R.string.problemsolver_title_background_data,
                check = ConfigUtils.isBackgroundDataRestricted(this)),
        Problem(title = R.string.problemsolver_title_notifications,
                check = ConfigUtils.isNotificationsDisabled(this)),
        Problem(title = R.string.problemsolver_title_fullscreen_notifications,
                check = ConfigUtils.isFullScreenNotificationsDisabled(this)),
        Problem(title = R.string.problemsolver_title_app_battery_usgae_optimized,
                check = !PowermanagerUtil.isIgnoringBatteryOptimizations(this)),
    )
}
```

**Mozilla VPN:**
- ❌ No proactive problem detection
- ❌ No UI to help users fix system-level issues

---

## Why Mozilla VPN Dies After 3AM Restart

1. **Battery Optimization is Enabled by Default**
   - Android sets battery optimization to "Optimized" for all apps by default
   - Mozilla VPN never asks to be exempted

2. **After Device Restart at 3AM:**
   - `BootReceiver` tries to start VPN service
   - Android 12+ blocks background service starts when battery optimization is on
   - Even if it starts, Android's Doze mode eventually kills it

3. **During Normal Usage:**
   - Battery optimization kicks in after a few hours
   - Android puts the app to sleep
   - VPN service gets terminated
   - No notification to user

---

## Why Threema Survives

1. **Battery Optimization is Detected and Disabled:**
   - Threema checks battery optimization status on startup
   - Shows warning UI if optimization is enabled
   - Guides user to disable it with step-by-step UI

2. **After Device Restart:**
   - `AutoStartNotifyReceiver` uses WorkManager (survives battery optimization better)
   - WorkManager has built-in retry mechanisms
   - Background connection is maintained properly

3. **Proactive Monitoring:**
   - `ProblemSolverActivity` constantly checks for issues
   - Users are notified immediately if settings change
   - Multiple fallback mechanisms

---

## Recommended Fixes for Mozilla VPN

### Critical (Must Have):
1. Add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission to AndroidManifest
2. Check battery optimization status on app startup
3. Show warning dialog when optimization is detected
4. Guide users to battery settings with intent

### Important (Should Have):
5. Implement `ProblemSolver` activity to detect multiple issues
6. Use WorkManager for boot restart (more reliable)
7. Add persistent notification explaining why battery optimization should be disabled

### Nice to Have:
8. Add telemetry to track how often VPN disconnects
9. Detect when VPN service is killed and notify user
10. Implement auto-reconnect with exponential backoff

---

## Related Issue
This analysis directly addresses: https://github.com/mozilla-mobile/mozilla-vpn-client/issues/10702

The issue reporter discovered this exact problem and manually disabled battery optimization, which fixed the disconnection issue (VPN ran for 33+ hours without disconnection).

---

## Code References

### Threema Files to Review:
- `threema-android/app/src/libre/AndroidManifest.xml` - Battery permission
- `threema-android/app/src/main/java/ch/threema/app/utils/PowermanagerUtil.java` - Detection
- `threema-android/app/src/main/java/ch/threema/app/activities/DisableBatteryOptimizationsActivity.java` - User guidance
- `threema-android/app/src/main/java/ch/threema/app/activities/ProblemSolverActivity.kt` - Proactive warnings
- `threema-android/app/src/main/java/ch/threema/app/receivers/AutoStartNotifyReceiver.kt` - Boot receiver

### Mozilla VPN Files to Modify:
- `mozilla-vpn-client/android/AndroidManifest.xml` - Add permission
- `mozilla-vpn-client/android/daemon/src/main/java/org/mozilla/firefox/vpn/daemon/BootReceiver.kt` - Improve boot handling
- Create new: Battery optimization checker and UI

