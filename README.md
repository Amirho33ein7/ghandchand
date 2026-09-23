# LowGuard — نگهبان قند

اپلیکیشن واقعی Android با Flutter برای ثبت قند خون، ثبت غذا و فعالیت، تحلیل الگوهای شخصی و یادآوری بررسی قند.

این برنامه تشخیص پزشکی نیست. موتور ریسک زمان افت قند را با قطعیت پیش‌بینی نمی‌کند و برای یادآوری بررسی قند ساخته شده است. برنامه مقدار غذا، تغییر دوز انسولین یا تغییر دارو تجویز نمی‌کند.

آستانه‌ها:
- Level 1: کمتر از 70 و حداقل 54 mg/dL
- Level 2: کمتر از 54 mg/dL
- Level 3: رخداد شدید همراه با اختلال جسمی/ذهنی و نیاز به کمک فرد دیگر، مستقل از عدد قند

منابع مرجع:
- American Diabetes Association — Standards of Care in Diabetes 2026
- CDC — Treatment of Low Blood Sugar (Hypoglycemia)

Flutter نسخه CI: 3.47.5
Android Gradle Plugin: 9.1.0
Gradle: 9.3.1
Java: 17

نسخه اولیه local-first است. داده واقعی سلامت، Secret، Token، API Key و Keystore نباید در Repository قرار گیرند.

Build محلی:
flutter pub get
flutter analyze
flutter test
flutter build apk
flutter build appbundle
