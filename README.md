# LowGuard — نگهبان قند

یک اپلیکیشن واقعی Android با Flutter برای ثبت قند خون، ثبت غذا و فعالیت، تحلیل الگوهای شخصی و یادآوری بررسی قند.

## اصل ایمنی
این برنامه تشخیص پزشکی نیست. موتور ریسک زمان افت قند را با قطعیت پیش‌بینی نمی‌کند و برای یادآوری بررسی قند طراحی شده است. این برنامه مقدار غذا، تغییر دوز انسولین یا تغییر دارو تجویز نمی‌کند.

آستانه‌ها:
- Level 1: کمتر از 70 و حداقل 54 mg/dL
- Level 2: کمتر از 54 mg/dL
- Level 3: رخداد شدید همراه با اختلال جسمی/ذهنی و نیاز به کمک فرد دیگر، مستقل از عدد قند

منابع مرجع: American Diabetes Association — Standards of Care in Diabetes 2026 و CDC — Treatment of Low Blood Sugar.

## فناوری
Flutter/Dart، SQLite، flutter_local_notifications، flutter_timezone، fl_chart و share_plus.

## Build
flutter pub get
flutter analyze
flutter test
flutter build apk
flutter build appbundle

## Notifications
Android 13+ به POST_NOTIFICATIONS نیاز دارد. Android 12+ برای Exact Alarm ممکن است دسترسی مخصوص بخواهد. در نبود آن زمان‌بندی غیر دقیق استفاده می‌شود. Full-screen intent عمداً استفاده نشده است.

## Privacy
نسخه اولیه local-first است. داده واقعی سلامت، Secret، Token، API Key و Keystore نباید در Repository قرار گیرند.

## Signing
نسخه اولیه CI برای ساخت قابل نصب از debug signing استفاده می‌کند. انتشار فروشگاهی به signing key امن نیاز دارد.
