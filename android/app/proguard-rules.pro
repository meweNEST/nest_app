# --- KEEP ALL FLUTTER PLUGINS ---
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }

# --- KEEP ALL PLUGIN REGISTRANTS ---
-keep class * extends io.flutter.plugins.GeneratedPluginRegistrant { *; }

# --- PREVENT REMOVAL OF PLUGIN IMPLEMENTATIONS ---
-keep class **.AppLinksPlugin { *; }
-keep class **.PathProviderPlugin { *; }
-keep class **.SharedPreferencesPlugin { *; }

# --- STRIPE / PUSH PROVISIONING ---
# Keep RN Stripe wrapper classes so R8 won't remove them
-keep class com.reactnativestripesdk.pushprovisioning.** { *; }

# Ignore missing underlying Stripe Android classes
-dontwarn com.stripe.android.pushProvisioning.**

# --- KEEP KOTLIN COROUTINES / SUPABASE ---
-keep class kotlinx.** { *; }
-keep class kotlin.** { *; }
-keep class org.jetbrains.annotations.** { *; }

# --- IGNORE MISSING PLAY CORE SPLIT INSTALL CLASSES ---
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.splitcompat.**