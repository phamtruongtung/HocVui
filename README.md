# Học Vui

Ứng dụng ôn bài mỗi ngày theo kiểu game cho học sinh lớp 6–9, theo Chương trình GDPT 2018 và bộ SGK
*Kết nối tri thức với cuộc sống*. Viết bằng **Flutter**, chạy trên **Android** và **web**, dữ liệu lưu trên **Firebase**.

## Tính năng

**Học sinh**
- Mỗi ngày có 2 đề, mỗi đề làm trong 30 phút. Năm môn (Toán, Ngữ văn, Tiếng Anh, KHTN, Lịch sử và Địa lý)
  xoay vòng theo chu kỳ 5 ngày, nên cứ 5 ngày mỗi môn được ôn 2 đề.
- Câu hỏi xếp từ dễ tới khó theo 4 mức: Nhận biết, Thông hiểu, Vận dụng, Vận dụng cao.
- Đề chỉ lấy các bài đã học tới bài admin đánh dấu "đang học tới", ưu tiên bài mới học và câu chưa gặp.
- Đồng hồ 30 phút không dừng được; hết giờ bài tự nộp.
- Xu thưởng theo số câu đúng và mức khó, chuỗi ngày học, điểm chuyên cần, khiên giữ chuỗi.
- Sổ tay lỗi sai: câu sai được hỏi lại sau 1, 3, 7 ngày.
- Xếp hạng tuần chung mọi lớp; top 3 nhận xu vào thứ Hai.
- Đổi xu lấy phần thưởng thật do bố mẹ đặt.
- Nhắc học trên Android từ 19:00, càng gần 23:59 càng nhắc dày và gắt hơn.

**Phụ huynh**
- Liên kết với con bằng mã `PH-xxxx`.
- Xem chuỗi, chuyên cần, hạng tuần, điểm theo môn, số đề 7 ngày qua, lỗi sai chưa sửa.
- Nhận thông báo khi con có lỗi sai mới, làm xong bài, xin đổi thưởng.
- Đặt phần thưởng, duyệt hoặc từ chối (từ chối thì con được hoàn xu).

**Quản trị viên** (nên dùng bản web trên máy tính)
- Tạo tài khoản học sinh và phụ huynh, khóa tài khoản, đổi lớp.
- Nhập mục lục SGK cho từng lớp, từng môn và đánh dấu bài đang học tới.
- Sinh câu hỏi bằng Claude theo từng bài, sửa rồi duyệt trước khi đưa vào đề.

## Luật chơi

| Hoạt động | Xu |
|---|---:|
| Hoàn thành một đề | +20 |
| Mỗi câu đúng Nhận biết / Thông hiểu / Vận dụng / Vận dụng cao | +1 / +2 / +4 / +6 |
| Đề đạt từ 9 điểm | +15 |
| Sửa đúng một câu trong sổ lỗi sai | +2 |
| Chuỗi 3 / 7 / 30 / 100 ngày | +30 / +80 / +400 / +1.500 |
| Xếp hạng tuần hạng 1 / 2 / 3 | +200 / +120 / +80 |

| Trong ngày | Kết quả |
|---|---|
| Xong cả 2 đề trước 23:59 | +1 chuyên cần (tối đa 100), chuỗi +1 |
| Mới xong 1 đề | −5 chuyên cần, mất chuỗi |
| Không làm đề nào | −10 chuyên cần, mất chuỗi |
| Có khiên (300 xu, giữ tối đa 2) | Giữ chuỗi, vẫn bị trừ chuyên cần |

Điểm thi đua tuần = tổng điểm các đề (thang 10) + 5 điểm mỗi ngày xong cả bài trước 21:00.

Các con số này nằm trong [lib/logic/rules.dart](lib/logic/rules.dart); số câu mỗi môn và lịch xoay vòng nằm trong
[lib/logic/subjects.dart](lib/logic/subjects.dart).

## Cài đặt lần đầu

### 1. Tạo repo GitHub và tải mã nguồn lên
1. Tạo repo mới (nên để **Private**), ví dụ `HocVui`.
2. Kéo thả toàn bộ thư mục dự án vào trang repo (Add file → Upload files).
3. Trang web GitHub **bỏ qua thư mục bắt đầu bằng dấu chấm**, nên 3 file workflow phải tạo tay:
   Add file → Create new file, gõ tên `.github/workflows/build-apk.yml`, dán nội dung file tương ứng, Commit.
   Làm tương tự với `deploy-web.yml` và `reset-password.yml`.

### 2. Tạo dự án Firebase
1. Vào <https://console.firebase.google.com> → **Add project**, đặt tên `hocvui` (không cần Google Analytics).
2. **Authentication → Get started → Sign-in method → Email/Password → Enable.**
   (Học Vui dùng tên đăng nhập; app tự đổi thành email dạng `tendangnhap@hocvui.app`.)
3. **Firestore Database → Create database** (chọn vùng `asia-southeast1`, chế độ production).
   Sang tab **Rules**, dán toàn bộ [firestore.rules](firestore.rules), bấm **Publish**.
4. **Project settings → Your apps → Add app → Android**, package name: `com.hocvui.hoc_vui`.
   Tải `google-services.json`, đưa lên repo vào đúng chỗ `android/app/google-services.json`.
5. **Add app → Web**, đặt tên `Học Vui Web`. Chép các giá trị `apiKey`, `appId`, `messagingSenderId`,
   `projectId`, `authDomain`, `storageBucket` vào [lib/firebase_web_options.dart](lib/firebase_web_options.dart).
6. **Authentication → Settings → Authorized domains → Add domain**: `hocvui.pages.dev`.

### 3. Tạo tài khoản quản trị
1. **Authentication → Users → Add user**: email `admin@hocvui.app`, đặt mật khẩu. Chép **User UID**.
2. **Firestore → Start collection** `users` → Document ID dán UID vừa chép, thêm các trường:
   - `role` (string) = `admin`
   - `username` (string) = `admin`
   - `displayName` (string) = tên của bạn
   - `active` (boolean) = `true`
3. Đăng nhập app bằng tên `admin` và mật khẩu vừa đặt.

### 4. Secret trên GitHub
Settings → Secrets and variables → Actions → New repository secret:

| Secret | Dùng cho | Lấy ở đâu |
|---|---|---|
| `KEYSTORE_BASE64` | Ký APK cố định để bản mới cài đè bản cũ | Dùng lại file `D:\Claude Code\MathJump-keys\KEYSTORE_BASE64.txt` |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | Đưa bản web lên `https://hocvui.pages.dev` | Giống repo Math Jump |
| `FIREBASE_SERVICE_ACCOUNT` | Đặt lại mật khẩu khi quên | Firebase → Project settings → Service accounts → Generate new private key, dán cả nội dung file JSON |

### 5. Lấy APK
Mỗi lần đẩy code lên, tab **Actions → Build APK** tự chạy (khoảng 8–10 phút). Mở lần chạy mới nhất,
tải file `HocVui-x.y.z` ở mục **Artifacts**, giải nén ra file `.apk` rồi cài lên điện thoại.

## Chuẩn bị nội dung (quản trị viên)
1. **Cài đặt → Claude API key**: tạo khóa ở <https://console.anthropic.com> → API Keys, dán vào và lưu.
   Khóa chỉ lưu trên máy/trình duyệt đang dùng, không gửi lên Firebase.
2. **Mục lục**: chọn lớp và môn, nhập mục lục SGK (mỗi dòng một bài, dòng chương bắt đầu bằng `#`).
   Có nút **Gợi ý bằng AI**, nhưng phải đối chiếu lại với sách thật. Chọn **Con đang học tới** bài nào.
3. **Sinh bằng AI**: chọn bài, chọn số câu mỗi mức, bấm sinh, đọc kỹ, sửa hoặc bỏ câu chưa tốt, rồi lưu.
   Mỗi môn cần ít nhất 5 câu đã duyệt thì mới ra đề được; nên có khoảng 20 câu mỗi bài để đề ít lặp.
4. **Câu hỏi**: duyệt các câu ở mục Chờ duyệt.
5. **Tài khoản**: tạo tài khoản phụ huynh (mã `PH-xxxx` tự sinh) và tài khoản các con.
6. Con đăng nhập, vào **Tôi**, nhập mã phụ huynh. Phụ huynh xác nhận ở **Cài đặt**.

Khi con quên mật khẩu: tab **Actions → Reset password → Run workflow**, nhập tên đăng nhập và mật khẩu mới.

Nếu app báo lỗi có chữ **"requires an index"** kèm một đường link, mở link đó (đăng nhập Google của dự án Firebase)
và bấm **Create index**; đợi vài phút rồi thử lại.

## Giới hạn hiện tại
- **Nhắc học chỉ có trên app Android** (hẹn giờ ngay trên máy). Bản web không nhắc được.
- **Thông báo cho phụ huynh** hiện trong mục Thông báo; trên Android chỉ bật lên màn hình khi app phụ huynh đang mở.
  Muốn đẩy thông báo cả khi app tắt cần thêm máy chủ gửi tin (giai đoạn sau).
- Xu, chuỗi, chuyên cần được tính trên máy của con, phù hợp dùng trong gia đình; chưa chống gian lận.
- Firebase gói miễn phí: 50.000 lượt đọc mỗi ngày, đủ cho vài học sinh với ngân hàng vài nghìn câu mỗi môn.

## Cấu trúc mã nguồn

```
lib/
  main.dart                   Khởi động Firebase, chọn màn hình theo vai trò
  version.dart                Phiên bản (phải khớp pubspec.yaml)
  firebase_web_options.dart   Cấu hình Firebase cho bản web
  theme.dart                  Màu sắc, phông chữ
  logic/
    subjects.dart             5 môn, số câu mỗi mức, lịch xoay vòng 5 ngày
    rules.dart                Xu, chuỗi, chuyên cần, sổ lỗi sai, xếp hạng
    exam_builder.dart         Chọn câu hỏi cho một đề
    dates.dart                Ngày, tuần
  models/models.dart          Hồ sơ, câu hỏi, đề, lỗi sai, phần thưởng...
  services/
    repo.dart                 Mọi thao tác với Firebase
    notifier.dart             Nhắc học (Android)
    ai_service.dart           Sinh câu hỏi bằng Claude API
  state/session.dart          Phiên đăng nhập
  screens/
    login_screen.dart
    student/                  Trang chủ, làm bài, kết quả, lỗi sai, xếp hạng, cửa hàng, hồ sơ
    parent/parent_shell.dart  Tổng quan, thông báo, phần thưởng, cài đặt
    admin/admin_shell.dart    Tài khoản, mục lục, câu hỏi, sinh bằng AI, cài đặt
  widgets/common.dart         Gà Chíp, nút, thẻ, nhãn dùng chung
test/                         Test luật chơi, tạo đề, phiên bản
firestore.rules               Luật bảo mật Firestore
tools/reset_password.mjs      Đặt lại mật khẩu (chạy bởi workflow)
```

## Đổi phiên bản
Sửa `version:` trong [pubspec.yaml](pubspec.yaml) (tăng số sau dấu `+` mỗi lần) **và** `kAppVersion` trong
[lib/version.dart](lib/version.dart). Test sẽ báo lỗi nếu hai chỗ không khớp.
