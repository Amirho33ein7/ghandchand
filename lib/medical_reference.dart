class MedicalReference {
  static const String version = '2026';

  static const double fastingPrediabetesMin = 100;
  static const double fastingDiabetesMin = 126;
  static const double ogttPrediabetesMin = 140;
  static const double ogttDiabetesMin = 200;
  static const double randomDiabetesMin = 200;

  static const double hypoLevel1 = 70;
  static const double hypoLevel2 = 54;

  static const String fastingDefinition =
      'حداقل ۸ ساعت بدون دریافت کالری';

  static String fastingBand(double mgDl) {
    if (mgDl < fastingPrediabetesMin) return 'زیر محدوده پیش‌دیابت';
    if (mgDl < fastingDiabetesMin) return 'محدوده پیش‌دیابت';
    return 'در محدوده تشخیصی دیابت؛ نیازمند تأیید پزشکی';
  }

  static String hypoBand(double mgDl) {
    if (mgDl < hypoLevel2) return 'افت قند سطح ۲';
    if (mgDl < hypoLevel1) return 'افت قند سطح ۱';
    return 'زیر آستانه افت قند نیست';
  }

  static const List<String> sources = [
    'American Diabetes Association — Standards of Care in Diabetes 2026',
    'World Health Organization — diabetes diagnosis criteria',
    'CDC — hypoglycemia safety guidance',
  ];
}