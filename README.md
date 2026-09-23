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

نسخه local-first است و برنامهٔ وعده‌ها به‌صورت روزانه و تکرارشونده فعال می‌ماند تا کاربر اطلاعات پایه را ویرایش کند. تنظیم مجدد اطلاعات باعث حذف زمان‌بندی قبلی و ایجاد برنامه جدید می‌شود. داده واقعی سلامت، Secret، Token، API Key و Keystore نباید در Repository قرار گیرند.

Build محلی:
flutter pub get
flutter analyze
flutter test
flutter build apk
flutter build appbundle


مرجع‌های پزشکی در نسخه 1.2:
- ADA Standards of Care in Diabetes 2026 — تشخیص دیابت و طبقه‌بندی هیپوگلیسمی
- World Health Organization — معیارهای تشخیصی دیابت
- برنامه از این مراجع برای آستانه‌های ایمنی و نمایش هشدار استفاده می‌کند؛ زمان وعده‌ها یک برنامه یادآوری شخصی است و جایگزین دستور درمانی پزشک نیست.
