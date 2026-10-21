// Đặt lại mật khẩu một tài khoản Học Vui. Chạy bởi .github/workflows/reset-password.yml.
import admin from 'firebase-admin';

const raw = process.env.SERVICE_ACCOUNT;
if (!raw) {
  console.error('Thiếu secret FIREBASE_SERVICE_ACCOUNT.');
  process.exit(1);
}
const username = (process.env.HV_USER || '').trim().toLowerCase();
const password = process.env.HV_PASSWORD || '';
if (!username) {
  console.error('Thiếu tên đăng nhập.');
  process.exit(1);
}
if (password.length < 6) {
  console.error('Mật khẩu mới cần ít nhất 6 ký tự.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(raw)) });
const email = `${username}@hocvui.app`;
try {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { password });
  console.log(`Đã đặt lại mật khẩu cho ${username}.`);
} catch (e) {
  console.error(`Không đặt lại được mật khẩu cho ${username}: ${e.message}`);
  process.exit(1);
}
