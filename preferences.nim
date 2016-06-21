import json
var prefs: JsonNode

when defined(android):
    import posix, os, strutils

    proc prefsFile(): string =
        var f {.global.}: string
        if f.isNil:
            var pkgName = readFile("/proc/" & $getpid() & "/cmdline")
            var i = 0
            while i < pkgName.len:
                if not (pkgName[i].isAlphaNumeric or pkgName[i] == '.'):
                    break
                inc i
            pkgName.setLen(i)
            let prefsDir = "/data/data/" & pkgName & "/shared_prefs"
            f = prefsDir & "/preferences.json"
        result = f

    proc loadPrefs(): JsonNode =
        let f = prefsFile()
        if fileExists(f):
            result = parseFile(f)
        else:
            result = newJObject()

    proc syncPreferences*() =
        if not prefs.isNil:
            let f = prefsFile()
            createDir(parentDir(f))
            writeFile(f, $prefs)

elif defined(js):
    proc loadPrefs(): JsonNode =
        var s: cstring
        {.emit: """
        try {
            if(typeof(Storage) !== 'undefined') {
                var p = window.localStorage['__nimapp_prefs'];
                if (p !== undefined) {
                    `s` = p;
                }
            }
        }
        catch(e) {}
        """.}
        if s.isNil:
            result = newJObject()
        else:
            result = parseJson($s)

    proc syncPreferences*() =
        if not prefs.isNil:
            let s : cstring = $prefs
            {.emit: """
            if(typeof(Storage) !== 'undefined') {
                try {
                    window.localStorage['__nimapp_prefs'] = `s`;
                }
                catch(e) {
                    console.log("WARNING: Could not store preferences: ", e);
                }
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
        if not prefs.isNil:
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
    import os

    const prefsFileName = getEnv("PREFS_FILE_NAME")
    when prefsFileName == "":
        {.error: "PREFS_FILE_NAME environment variable is not defined. Run nim with --putenv:PREFS_FILE_NAME=<value> option".}

    proc prefsFile(): string =
        when defined(windows):
            result = getEnv("APPDATA") / prefsFileName
        else:
            result = expandTilde("~" / prefsFileName)

    proc loadPrefs(): JsonNode =
        let f = prefsFile()
        if fileExists(f):
            result = parseFile(f)
        else:
            result = newJObject()

    proc syncPreferences*() =
        if not prefs.isNil:
            let f = prefsFile()
            createDir(parentDir(f))
            writeFile(f, $prefs)

proc sharedPreferences*(): JsonNode =
    if prefs.isNil:
        prefs = loadPrefs()
    result = prefs
