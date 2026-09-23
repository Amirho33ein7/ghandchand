# Changelog

## 1.2.0
- Added a complete editable profile/settings page for all onboarding inputs.
- Meal reminders now repeat daily until the user changes the profile; the app no longer relies on a seven-day reminder horizon.
- Added a scheduled notification test from Settings.
- Centralized 2026 medical reference thresholds and sources.
- Rebuilt the meal schedule immediately after profile edits and rescheduled notifications.


## 1.1.0
- Added a personalized daily meal-time algorithm using wake/sleep schedule, selected meal count, glucose inputs, and hypoglycemia-risk signals.
- Added scheduled meal notifications for the calculated meal times.
- Meal notifications are planned for the current day and the next two days and use the phone's local timezone.
- Added automated tests for meal scheduling.
- Kept meal timing as a reminder feature; the app does not prescribe food quantities or medication/insulin changes.

## 1.0.0
- Initial Android release foundation.
- Notification permission and notification settings controls.
- GitHub Actions APK/AAB build and release publishing.
- Flutter Android foundation.
- Persian onboarding.
- Local glucose/meal/activity/hypoglycemia storage.
- Non-diagnostic personal risk windows.
- Notification scheduling foundation.
- Initial algorithm tests.
