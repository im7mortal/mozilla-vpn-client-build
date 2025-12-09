# Visual Comparison: Threema vs Mozilla VPN - Restart Survival

## The Problem

**User's 3AM Restart Scenario:**
- Device restarts every night at 3:00 AM
- **Threema-libre**: ✅ Survives restart, reconnects automatically
- **Mozilla VPN**: ❌ Often fails to restart, stays disconnected

---

## Root Cause

Mozilla VPN **does not handle battery optimization**, causing Android to kill the VPN service.

---

## Side-by-Side Comparison

| Feature | Threema-libre | Mozilla VPN | Impact |
|---------|---------------|-------------|---------|
| **Battery Optimization Permission** | ✅ `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | ❌ Missing | **CRITICAL** |
| **Battery Status Detection** | ✅ Checks on every app start | ❌ Never checks | **CRITICAL** |
| **User Warning UI** | ✅ Toolbar warning button + Problem Solver | ❌ No warnings | **CRITICAL** |
| **Boot Receiver** | ✅ WorkManager with retry | ✅ Direct service start | Medium |
| **Background Restriction Check** | ✅ `isBackgroundRestricted()` | ❌ Not checked | High |
| **Background Data Check** | ✅ `isBackgroundDataRestricted()` | ❌ Not checked | High |
| **Notification Permission Check** | ✅ Checked + warned | ❌ Not checked | Medium |
| **Foreground Service Type** | `REMOTE_MESSAGING` | `SYSTEM_EXEMPTED` | Low |

---

## How Threema Detects Problems

### 1. Toolbar Warning Button
```java
// HomeActivity.java line 1087-1091
this.toolbarWarningButton = findViewById(R.id.toolbar_warning);
this.toolbarWarningButton.setOnClickListener(v -> {
    Intent intent = ProblemSolverActivity.createIntent(HomeActivity.this);
    problemSolverLauncher.launch(intent);
});
```

### 2. Multiple System Checks
```java
// HomeActivity.java line 766-776
private boolean shouldShowToolbarWarning() {
    boolean isBatteryOptimized = !PowermanagerUtil.isIgnoringBatteryOptimizations(appContext);
    return
        ConfigUtils.isBackgroundRestricted(appContext) ||
        ConfigUtils.isBackgroundDataRestricted(appContext) ||
        ConfigUtils.isNotificationsDisabled(appContext) ||
        (isVoipEnabled && ConfigUtils.isFullScreenNotificationsDisabled(appContext)) ||
        (useThreemaPush && isBatteryOptimized) ||
        (hasRunningSessions && isBatteryOptimized);
}
```

### 3. System Check Implementations

#### Battery Optimization Check
```java
// PowermanagerUtil.java line 142-155
public static boolean isIgnoringBatteryOptimizations(@NonNull Context context) {
    final PowerManager powerManager = (PowerManager) context.getApplicationContext()
        .getSystemService(POWER_SERVICE);
    return powerManager.isIgnoringBatteryOptimizations(context.getPackageName());
}
```

#### Background Restriction Check
```java
// ConfigUtils.java line 1534-1541
public static boolean isBackgroundRestricted(@NonNull Context context) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        return activityManager.isBackgroundRestricted();
    }
    return false;
}
```

#### Background Data Restriction Check
```java
// ConfigUtils.java line 1549-1552
public static boolean isBackgroundDataRestricted(@NonNull Context context) {
    ConnectivityManager connectivityManager = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
    return connectivityManager.getRestrictBackgroundStatus() == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED;
}
```

#### Notification Check
```java
// ConfigUtils.java line 1574-1576
public static boolean isNotificationsDisabled(@NonNull Context context) {
    return !NotificationManagerCompat.from(context).areNotificationsEnabled();
}
```

---

## User Flow Comparison

### Threema User Experience:
1. **App Start**: Threema checks all system settings
2. **Problem Detected**: Shows ⚠️ warning icon in toolbar
3. **User Clicks Warning**: Opens Problem Solver activity
4. **Problem List**: Shows all detected issues with explanations
5. **User Clicks Issue**: Direct intent to system settings for that specific issue
6. **Problem Solved**: Warning icon disappears

### Mozilla VPN User Experience:
1. **App Start**: VPN starts normally
2. **Few Hours Later**: VPN disconnects silently
3. **After Restart**: VPN doesn't reconnect
4. **User**: "Why is my VPN not working?"
5. **User**: Must manually discover battery optimization issue
6. **User**: Must manually navigate to settings

---

## Technical Breakdown: Why VPN Dies

### Timeline of VPN Death:

```
12:00 AM - User enables Mozilla VPN
12:00 AM - VPN service starts in foreground
01:00 AM - Device enters Doze mode
01:00 AM - Battery optimization starts limiting background apps
02:30 AM - Android decides Mozilla VPN is using too much battery
02:30 AM - Android puts VPN app to sleep
02:30 AM - VPN connection drops (no notification to user)
03:00 AM - Device restarts (scheduled restart)
03:00 AM - BootReceiver fires
03:00 AM - Tries to start VPN service from background
03:00 AM - Android blocks it (battery optimization enabled)
03:00 AM - VPN stays OFF
08:00 AM - User wakes up, discovers VPN is off
08:00 AM - User manually restarts VPN
```

### Why Threema Survives:

```
12:00 AM - User opens Threema
12:00 AM - Threema checks battery optimization
12:00 AM - Detects optimization is enabled
12:00 AM - Shows ⚠️ warning in toolbar
12:05 AM - User clicks warning, sees explanation
12:06 AM - User disables battery optimization for Threema
12:06 AM - Threema warning icon disappears
01:00 AM - Device enters Doze mode
01:00 AM - Battery optimization starts, but Threema is exempt
02:00 AM - Threema still running, connection maintained
03:00 AM - Device restarts
03:00 AM - BootReceiver fires
03:00 AM - WorkManager schedules AutostartWorker
03:00 AM - Threema service restarts successfully (exempt from battery optimization)
03:01 AM - Connection re-established
08:00 AM - User wakes up, Threema works perfectly
```

---

## Code Files to Review

### Threema Key Files:

1. **Permission Declaration**
   - `threema-android/app/src/libre/AndroidManifest.xml` (line 6)

2. **Detection Logic**
   - `threema-android/app/src/main/java/ch/threema/app/utils/PowermanagerUtil.java`
   - `threema-android/app/src/main/java/ch/threema/app/utils/ConfigUtils.java` (lines 1534-1576)

3. **User Interface**
   - `threema-android/app/src/main/java/ch/threema/app/home/HomeActivity.java` (lines 759-776, 1087-1091)
   - `threema-android/app/src/main/java/ch/threema/app/activities/ProblemSolverActivity.kt` (lines 74-113)
   - `threema-android/app/src/main/java/ch/threema/app/activities/DisableBatteryOptimizationsActivity.java`

4. **Boot Restart**
   - `threema-android/app/src/main/java/ch/threema/app/receivers/AutoStartNotifyReceiver.kt`
   - `threema-android/app/src/main/java/ch/threema/app/workers/AutostartWorker.kt`

5. **Foreground Service**
   - `threema-android/app/src/main/java/ch/threema/app/services/ThreemaPushService.kt` (lines 50-253)

### Mozilla VPN Key Files:

1. **Current Boot Receiver (Insufficient)**
   - `mozilla-vpn-client/android/daemon/src/main/java/org/mozilla/firefox/vpn/daemon/BootReceiver.kt`

2. **VPN Service**
   - `mozilla-vpn-client/android/daemon/src/main/java/org/mozilla/firefox/vpn/daemon/VPNService.kt`

3. **Manifest**
   - `mozilla-vpn-client/android/AndroidManifest.xml`
   - `mozilla-vpn-client/android/daemon/src/main/AndroidManifest.xml`

---

## Implementation Recommendation

### Priority 1 (Must Have - Fixes the core issue):
1. Add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission to AndroidManifest
2. Create `BatteryOptimizationHelper.kt` to check status
3. Show persistent warning in main UI when optimization is detected
4. Add button to guide users to system settings

### Priority 2 (Should Have - Improves reliability):
5. Implement comprehensive system checks (background restrictions, data restrictions)
6. Create "Problem Solver" activity listing all issues
7. Add telemetry to track disconnection patterns
8. Improve boot receiver with WorkManager

### Priority 3 (Nice to Have - Better UX):
9. Add in-app tutorial about battery optimization
10. Detect when VPN service is killed and notify user
11. Implement auto-reconnect with exponential backoff
12. Add persistent notification explaining why battery optimization should be disabled

---

## Testing Plan

1. **Enable battery optimization** for Mozilla VPN (Settings → Apps → Mozilla VPN → Battery → Optimized)
2. **Start VPN** and wait 2-4 hours
3. **Observe**: VPN disconnects (reproduces issue)
4. **Apply fixes** from Priority 1
5. **Test again**: VPN should show warning about battery optimization
6. **Disable battery optimization** through the new UI
7. **Test again**: VPN should survive for 24+ hours
8. **Restart device**: VPN should automatically reconnect

---

## Related GitHub Issue

**Mozilla VPN Issue #10702**: "Mozilla VPN Android on android will disable itself without a warning after a couple of hours"
- URL: https://github.com/mozilla-mobile/mozilla-vpn-client/issues/10702
- Status: Open (as of the search results)
- Reporter's Solution: Manually changed battery optimization from "Optimized" to "Unrestricted"
- Result: VPN ran for 33+ hours without disconnection
- **This confirms the root cause analysis above**

---

## Conclusion

**Threema survives restarts** because it:
1. ✅ Proactively detects battery optimization issues
2. ✅ Warns users with visible UI indicators
3. ✅ Guides users to fix the problem
4. ✅ Uses robust restart mechanisms

**Mozilla VPN fails** because it:
1. ❌ Never checks battery optimization
2. ❌ Never warns users
3. ❌ Gets killed by Android's battery optimization
4. ❌ Can't restart from background when optimization is enabled

**The fix is straightforward**: Implement the same battery optimization checks and user guidance that Threema uses.

