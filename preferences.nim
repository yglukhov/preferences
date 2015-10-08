import json

var prefs: JsonNode

when defined(android):
    import jnim

    proc loadPrefs(): JsonNode = newJObject()

    proc syncPreferences*() =
        discard
elif defined(js):
    proc loadPrefs(): JsonNode = newJObject()

    proc syncPreferences*() =
        discard
elif defined(macosx) or defined(ios):
    {.emit: """
    #include <CoreFoundation/CoreFoundation.h>
    static const CFStringRef kPrefsKey = CFSTR("prefs");
    """.}

    proc loadPrefs(): JsonNode =
        var prefsJsonString: cstring
        {.emit: """
        CFBundleRef bundle = CFBundleGetMainBundle();
        CFStringRef bundleId = CFBundleGetIdentifier(bundle);
        CFStringRef jsStr = CFPreferencesCopyValue(kPrefsKey, bundleId, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
        if (jsStr != NULL) {
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
        CFBundleRef bundle = CFBundleGetMainBundle();
        CFStringRef bundleId = CFBundleGetIdentifier(bundle);
        CFStringRef jsStr = CFStringCreateWithCString(kCFAllocatorDefault, `prefsJsonString`, kCFStringEncodingUTF8);
        if (jsStr != NULL) {
            CFPreferencesSetValue(kPrefsKey, jsStr, bundleId, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
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
