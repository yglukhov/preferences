import json

var prefs: JsonNode

when defined(android):
    import jnim

    proc loadPrefs(): JsonNode = newJObject()

    proc syncPreferences*() =
        discard
elif defined(js):
    proc loadPrefs(): JsonNode =
        var s: cstring
        {.emit: """
        if(typeof(Storage) !== 'undefined') {
            `s` = window.localStorage['__nimapp_prefs'];
        }
        """.}
        if s.isNil:
            result = newJObject()
        else:
            result = parseJson($s)

    proc syncPreferences*() =
        let s : cstring = $prefs
        {.emit: """
        if(typeof(Storage) !== 'undefined') {
            window.localStorage['__nimapp_prefs'] = `s`;
        }
        """.}

elif defined(macosx) or defined(ios):
    {.emit: """
    #include <CoreFoundation/CoreFoundation.h>
    static const CFStringRef kPrefsKey = CFSTR("prefs");
    """.}

    proc loadPrefs(): JsonNode =
        var prefsJsonString: cstring
        {.emit: """
        CFStringRef jsStr = CFPreferencesCopyValue(kPrefsKey, kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
        if (jsStr) {
            CFIndex bufLen = CFStringGetMaximumSizeForEncoding(CFStringGetLength(jsStr), kCFStringEncodingUTF8);
            `prefsJsonString` = malloc(bufLen);
            CFStringGetCString(jsStr, `prefsJsonString`, bufLen, kCFStringEncodingUTF8);
            CFRelease(jsStr);
        }
        """.}
        if not prefsJsonString.isNil:
            result = parseJson($prefsJsonString)
        else:
            result = newJObject()
        {.emit:"""
        if (`prefsJsonString`) { free(`prefsJsonString`); }
        """.}

    proc syncPreferences*() =
        let prefsJsonString : cstring = $prefs
        {.emit: """
        CFStringRef jsStr = CFStringCreateWithCString(kCFAllocatorDefault, `prefsJsonString`, kCFStringEncodingUTF8);
        if (jsStr) {
            CFPreferencesSetValue(kPrefsKey, jsStr, kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
            CFPreferencesSynchronize(kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
            CFRelease(jsStr);
        }
        """.}
else:
    proc loadPrefs(): JsonNode = newJObject()

    proc syncPreferences*() =
        discard

proc sharedPreferences*(): JsonNode =
    if prefs.isNil:
        prefs = loadPrefs()
    result = prefs
