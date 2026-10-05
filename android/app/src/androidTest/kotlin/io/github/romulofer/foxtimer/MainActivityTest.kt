package io.github.romulofer.foxtimer

import android.Manifest
import android.os.Build
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.ActivityTestRule
import dev.flutter.plugins.integration_test.FlutterTestRunner
import org.junit.Rule
import org.junit.runner.RunWith

// Runs the Dart integration tests (integration_test/*.dart) as Android
// instrumentation tests:
//   cd android && ./gradlew app:connectedDebugAndroidTest \
//     -Ptarget=`pwd`/../integration_test/android_test.dart
@RunWith(FlutterTestRunner::class)
class MainActivityTest {
    // FlutterTestRunner only honors an ActivityTestRule, so permissions are
    // granted from its launch hook instead of a GrantPermissionRule.
    @Rule
    @JvmField
    val rule: ActivityTestRule<MainActivity> =
        object : ActivityTestRule<MainActivity>(MainActivity::class.java, true, false) {
            override fun beforeActivityLaunched() {
                // The system permission prompt can't be answered from Dart.
                if (Build.VERSION.SDK_INT >= 33) {
                    val instrumentation = InstrumentationRegistry.getInstrumentation()
                    instrumentation.uiAutomation.grantRuntimePermission(
                        instrumentation.targetContext.packageName,
                        Manifest.permission.POST_NOTIFICATIONS,
                    )
                }
            }
        }
}
