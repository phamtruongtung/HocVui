# Bản release được Android (R8) thu gọn mã. Thư viện nhắc học
# flutter_local_notifications dùng Gson để lưu lịch nhắc; thiếu các luật
# dưới đây thì hẹn giờ/xóa nhắc báo lỗi "Missing type parameter".
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }

# Flutter tham chiếu tới thư viện Play Core (tải module theo yêu cầu) mà app
# không dùng; thiếu các dòng này R8 báo "Missing classes detected" và dừng build.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
