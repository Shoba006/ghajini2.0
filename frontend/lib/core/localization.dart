enum AppLanguage { en, hi, pa }

class AppStrings {
  static AppLanguage currentLang = AppLanguage.en;

  static const Map<String, Map<AppLanguage, String>> _strings = {
    'app_title': {
      AppLanguage.en: "Ghajini 2.0",
      AppLanguage.hi: "गजनी 2.0",
      AppLanguage.pa: "ਗਜਨੀ 2.0",
    },
    'greeting_hello': {
      AppLanguage.en: "Hello!",
      AppLanguage.hi: "नमस्ते!",
      AppLanguage.pa: "ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ!",
    },
    'who_is_this': {
      AppLanguage.en: "Who is this?",
      AppLanguage.hi: "यह कौन है?",
      AppLanguage.pa: "ਇਹ ਕੌਣ ਹੈ?",
    },
    'talk_to_companion': {
      AppLanguage.en: "Talk to Ghajini",
      AppLanguage.hi: "गजनी से बात करें",
      AppLanguage.pa: "ਗਜਨੀ ਨਾਲ ਗੱਲ ਕਰੋ",
    },
    'ask_anything': {
      AppLanguage.en: "Ask me anything",
      AppLanguage.hi: "कुछ भी पूछें",
      AppLanguage.pa: "ਕੁਝ ਵੀ ਪੁੱਛੋ",
    },
    'askGhajini': {
      AppLanguage.en: "Ask me anything",
      AppLanguage.hi: "कुछ भी पूछें",
      AppLanguage.pa: "ਕੁਝ ਵੀ ਪੁੱਛੋ",
    },
    'call_family': {
      AppLanguage.en: "Call Family",
      AppLanguage.hi: "परिवार को फोन करें",
      AppLanguage.pa: "ਪਰਿਵਾਰ ਨੂੰ ਫ਼ੋਨ ਕਰੋ",
    },
    'sos_help': {
      AppLanguage.en: "SOS HELP",
      AppLanguage.hi: "मदद चाहिए (SOS)",
      AppLanguage.pa: "ਮਦਦ ਚਾਹੀਦੀ ਹੈ (SOS)",
    },
    'caregiver_notified': {
      AppLanguage.en: "Your family has been told.",
      AppLanguage.hi: "आपके परिवार को बता दिया गया है।",
      AppLanguage.pa: "ਤੁਹਾਡੇ ਪਰਿਵਾਰ ਨੂੰ ਦੱਸ ਦਿੱਤਾ ਗਿਆ ਹੈ।",
    },
    'not_sure_fallback': {
      AppLanguage.en: "I am not sure. Shall I call your family?",
      AppLanguage.hi: "मुझे पक्का नहीं पता। क्या मैं आपके परिवार को फोन करूं?",
      AppLanguage.pa: "ਮੈਨੂੰ ਪੱਕਾ ਨਹੀਂ ਪਤਾ। ਕੀ ਮੈਂ ਤੁਹਾਡੇ ਪਰਿਵਾਰ ਨੂੰ ਫ਼ੋਨ ਕਰਾਂ?",
    },
    'notSure': {
      AppLanguage.en: "I am not sure. Shall I call your family?",
      AppLanguage.hi: "मुझे पक्का नहीं पता। क्या मैं आपके परिवार को फोन करूं?",
      AppLanguage.pa: "ਮੈਨੂੰ ਪੱਕਾ नहीं पता। ਕੀ ਮੈਂ ਤੁਹਾਡੇ ਪਰਿਵਾਰ ਨੂੰ ਫ਼ੋਨ ਕਰਾਂ?",
    },
    'thinking': {
      AppLanguage.en: "Let me think...",
      AppLanguage.hi: "ज़रा सोचने दीजिए...",
      AppLanguage.pa: "ਮੈਨੂੰ ਸੋਚਣ ਦਿਓ...",
    },
    'press_to_speak': {
      AppLanguage.en: "Press to speak",
      AppLanguage.hi: "बोलने के लिए दबाएं",
      AppLanguage.pa: "ਬੋਲਣ ਲਈ ਦਬਾਓ",
    },
    'all_caught_up': {
      AppLanguage.en: "All caught up! No pending reminders.",
      AppLanguage.hi: "सब पूरा हो गया! कोई काम बाकी नहीं है।",
      AppLanguage.pa: "ਸਭ ਪੂਰਾ ਹੋ ਗਿਆ! ਕੋਈ ਕੰਮ ਬਾਕੀ ਨਹੀਂ।",
    },
    'due_reminder': {
      AppLanguage.en: "Medication Reminder",
      AppLanguage.hi: "दवाई का समय",
      AppLanguage.pa: "ਦਵਾਈ ਦਾ ਸਮਾਂ",
    },
  };

  /// Retrieves localized string. Supports both:
  /// `AppStrings.get('key')` and `AppStrings.get(langCode, 'key')`
  static String get(String keyOrLang, [String? optionalKey]) {
    String key;
    AppLanguage lang = currentLang;

    if (optionalKey != null) {
      final code = keyOrLang.toLowerCase();
      if (code == 'hi') {
        lang = AppLanguage.hi;
      } else if (code == 'pa') {
        lang = AppLanguage.pa;
      } else {
        lang = AppLanguage.en;
      }
      key = optionalKey;
    } else {
      key = keyOrLang;
    }

    if (key == 'notSure') key = 'not_sure_fallback';
    if (key == 'askGhajini') key = 'ask_anything';

    if (_strings.containsKey(key)) {
      return _strings[key]![lang] ?? _strings[key]![AppLanguage.en]!;
    }
    return key;
  }

  static void setLanguage(String code) {
    switch (code.toLowerCase()) {
      case 'hi':
        currentLang = AppLanguage.hi;
        break;
      case 'pa':
        currentLang = AppLanguage.pa;
        break;
      default:
        currentLang = AppLanguage.en;
        break;
    }
  }

  static String get currentCode {
    switch (currentLang) {
      case AppLanguage.hi:
        return 'hi';
      case AppLanguage.pa:
        return 'pa';
      default:
        return 'en';
    }
  }

  static String get currentLocaleName {
    switch (currentLang) {
      case AppLanguage.hi:
        return 'hi-IN';
      case AppLanguage.pa:
        return 'pa-IN';
      default:
        return 'en-IN';
    }
  }
}
