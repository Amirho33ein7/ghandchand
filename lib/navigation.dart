import 'package:flutter/foundation.dart';

final ValueNotifier<String?> pendingNotificationPayload = ValueNotifier<String?>(null);

void handleNotificationPayload(String? payload) {
  if (payload != null && payload.isNotEmpty) {
    pendingNotificationPayload.value = payload;
  }
}
