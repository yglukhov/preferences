import json
var prefs: JsonNode

when defined(android):
    import os, jnim
    import android/extras/pathutils
    import android/app/activity
    import android/preference/preference_manager
    import android/content/shared_preferences

    proc savePrefsToSharedPrefs(j: JsonNode) =
        let sp = PreferenceManager.getDefaultSharedPreferences(currentActivity())
        let e = sp.edit()
        var p = ""
        toUgly(p, j)
        e.putString("__nimapp_prefs", p).apply()

    proc loadPrefsFromSharedPrefs(): JsonNode =
        let sp = PreferenceManager.getDefaultSharedPreferences(currentActivity())
        let s = sp.getString("__nimapp_prefs", "")
        if s.len != 0:
            try:
                result = parseJson(s)
            except:
                result = newJObject()
        else:
            result = newJObject()

    proc loadPrefs(): JsonNode =
        result = loadPrefsFromSharedPrefs()

    proc syncPreferences*() =
        if not prefs.isNil:
            savePrefsToSharedPrefs(prefs)

elif defined(js):
    proc loadPrefs(): JsonNode =
        var s: cstring
        {.emit: """
        try {
            if (typeof(Storage) !== 'undefined') {
                var p = window.localStorage['__nimapp_prefs'];
                if (typeof(p) === 'string') {
                    `s` = p;
                }
            }
        }
        catch(e) {}
        """.}
        if s.isNil:
            result = newJObject()
        else:
            try:
                result = parseJson($s)
            except:
                result = newJObject()

    proc syncPreferences*() =
        if not prefs.isNil:
            let s : cstring = $prefs
            {.emit: """
            if(typeof(Storage) !== 'undefined') {
                try {
                    window.localStorage['__nimapp_prefs'] = `s`;
                }
                catch(e) {
                    console.warn("Could not store preferences: ", e);
                }
            }
            """.}

elif defined(emscripten):
    import jsbind/emscripten

    proc c_free(p: pointer) {.importc: "free".}

    proc loadPrefs(): JsonNode =
        let si = EM_ASM_INT("""
        try {
            if (typeof(Storage) !== 'undefined') {
                var p = window.localStorage['__nimapp_prefs'];
                if (typeof(p) === 'string') {
                    return allocate(intArrayFromString(p), 'i8', ALLOC_NORMAL);
                }
            }
        }
        catch(e) {}
        return 0;
        """)
        let s = cast[cstring](si)
        if s.isNil:
            result = newJObject()
        else:
            try:
                result = parseJson($s)
            except:
                result = newJObject()
            c_free(s)

    proc syncPreferences*() =
        if not prefs.isNil:
            let s : cstring = $prefs
            discard EM_ASM_INT("""
            if(typeof(Storage) !== 'undefined') {
                try {
                    window.localStorage['__nimapp_prefs'] = UTF8ToString($0);
                }
                catch(e) {
                    console.warn("Could not store preferences: ", e);
                }
            }
            """, s)

elif defined(macosx) or defined(ios):
    import plists, darwin/core_foundation
    const prefsKey = "prefs0"

    proc loadPrefs(): JsonNode =
        let k = CFStringCreate(prefsKey)
        let p = CFPreferencesCopyAppValue(k, kCFPreferencesCurrentApplication)
        k.release()
        if not p.isNil:
            result = CFPropertyListToJson(p)
            p.release()
        if result.isNil: result = newJObject()

    proc syncPreferences*() =
        if not prefs.isNil:
            let p = CFPropertyListCreateWithJson(prefs)
            if not p.isNil:
                let k = CFStringCreate(prefsKey)
                CFPreferencesSetAppValue(k, p, kCFPreferencesCurrentApplication)
                k.release()
                p.release()
                discard CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
else:
    import os

    const prefsFileName = getEnv("PREFS_FILE_NAME")
    when prefsFileName.len == 0:
        static:
            echo "PREFS_FILE_NAME environment variable is not defined. Run nim with --putenv:PREFS_FILE_NAME=<value> option"

    proc prefsFile(): string =
        when prefsFileName.len == 0:
            let prefsFileName = splitFile(getAppFilename()).name
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
        prefs = try: loadPrefs() except: newJObject()
    result = prefs
