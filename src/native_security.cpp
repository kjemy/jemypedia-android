#include <stdint.h>
#include <string.h>
#include <stdio.h>

#if defined(_WIN32)
#define FFI_EXPORT __declspec(dllexport)
#include <windows.h>
#else
#define FFI_EXPORT __attribute__((visibility("default")))
#include <sys/ptrace.h>
#include <unistd.h>
#endif

extern "C" {

// 1. Debugger Detection
FFI_EXPORT int32_t is_debugger_present() {
#if defined(_WIN32)
    if (IsDebuggerPresent()) {
        return 1;
    }
    BOOL isRemote = FALSE;
    if (CheckRemoteDebuggerPresent(GetCurrentProcess(), &isRemote) && isRemote) {
        return 1;
    }
    return 0;
#else
    // On Android/Linux, we return 0 here and do it in Kotlin/proc-fs check.
    return 0;
#endif
}

// 2. License Check Signature Validator (in native code)
FFI_EXPORT int32_t verify_license_hash(const char* email, const char* hwid, const char* signature) {
    if (!email || !hwid || !signature) return 0;
    
    // Compute simple DJB2 hash representing license validation
    uint32_t hash = 5381;
    const char* p = email;
    while (*p) {
        hash = ((hash << 5) + hash) + *p;
        p++;
    }
    p = hwid;
    while (*p) {
        hash = ((hash << 5) + hash) + *p;
        p++;
    }
    const char* salt = "jemy_security_salt_2026";
    p = salt;
    while (*p) {
        hash = ((hash << 5) + hash) + *p;
        p++;
    }
    
    char computed_sig[32];
#if defined(_WIN32)
    sprintf_s(computed_sig, "%08X", hash);
#else
    sprintf(computed_sig, "%08X", hash);
#endif
    
    if (strcmp(computed_sig, signature) == 0) {
        return 1;
    }
    return 0;
}

}
