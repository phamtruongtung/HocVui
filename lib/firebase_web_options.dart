import 'package:firebase_core/firebase_core.dart';

/// Cấu hình Firebase cho bản web (Firebase Console → Project settings →
/// Your apps → Học Vui Web). Các giá trị này là công khai, được phép nằm
/// trong mã nguồn; dữ liệu được bảo vệ bằng firestore.rules.
///
/// Còn để 'REPLACE' thì bản web báo "chưa cấu hình Firebase".
const webFirebaseOptions = FirebaseOptions(
  apiKey: 'REPLACE',
  appId: 'REPLACE',
  messagingSenderId: 'REPLACE',
  projectId: 'REPLACE',
  authDomain: 'REPLACE',
  storageBucket: 'REPLACE',
);

bool get webFirebaseConfigured => webFirebaseOptions.apiKey != 'REPLACE';
