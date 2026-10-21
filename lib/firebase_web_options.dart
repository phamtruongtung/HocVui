import 'package:firebase_core/firebase_core.dart';

/// Cấu hình Firebase cho bản web (Firebase Console → Project settings →
/// Your apps → Học Vui Web). Các giá trị này là công khai, được phép nằm
/// trong mã nguồn; dữ liệu được bảo vệ bằng firestore.rules.
///
/// Còn để 'REPLACE' thì bản web báo "chưa cấu hình Firebase".
const webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDT-IxkllClyhKG5SoK6OnHDhjJAgEuw_U',
  appId: '1:424453700433:web:a855dce8438e97c6513170',
  messagingSenderId: '424453700433',
  projectId: 'hocvui-645b7',
  authDomain: 'hocvui-645b7.firebaseapp.com',
  storageBucket: 'hocvui-645b7.firebasestorage.app',
);

bool get webFirebaseConfigured => webFirebaseOptions.apiKey != 'REPLACE';
