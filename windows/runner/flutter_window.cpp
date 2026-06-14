#include "flutter_window.h"

#include <optional>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

// Returns the number of PHYSICALLY connected display outputs (works in clone/extend/single modes)
// Uses CCD (Connected Configuration Displays) API which is more reliable than EnumDisplayMonitors
// EnumDisplayMonitors only counts LOGICAL monitors and misses clone mode entirely
#include <psapi.h>
#include <algorithm>
#include <string>

bool IsBlacklistedProcessRunning() {
    DWORD aProcesses[1024], cbNeeded, cProcesses;
    unsigned int i;

    if (!EnumProcesses(aProcesses, sizeof(aProcesses), &cbNeeded)) {
        return false;
    }

    cProcesses = cbNeeded / sizeof(DWORD);
    std::vector<std::string> blacklist = {
        "obs64.exe", "obs32.exe", 
        "audacity.exe", "audition.exe",
        "camtasia.exe", "camrecorder.exe",
        "bandicam.exe", "action.exe",
        "fraps.exe", "xsplit.core.exe",
        "soundforge.exe", "reaper.exe"
    };

    for (i = 0; i < cProcesses; i++) {
        if (aProcesses[i] != 0) {
            char szProcessName[MAX_PATH] = "<unknown>";
            HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, aProcesses[i]);
            if (NULL != hProcess) {
                HMODULE hMod;
                DWORD cbNeededMod;
                if (EnumProcessModules(hProcess, &hMod, sizeof(hMod), &cbNeededMod)) {
                    GetModuleBaseNameA(hProcess, hMod, szProcessName, sizeof(szProcessName));
                    std::string processName(szProcessName);
                    std::transform(processName.begin(), processName.end(), processName.begin(),
                        [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
                    for (const auto& banned : blacklist) {
                        if (processName == banned) {
                            CloseHandle(hProcess);
                            return true;
                        }
                    }
                }
                CloseHandle(hProcess);
            }
        }
    }
    return false;
}

int GetPhysicalDisplayCount() {
    UINT32 pathCount = 0;
    UINT32 modeCount = 0;

    // First get required buffer sizes for ACTIVE paths only
    LONG result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &pathCount, &modeCount);
    if (result != ERROR_SUCCESS || pathCount == 0) {
        // Fallback: use GetSystemMetrics which at least counts logical monitors
        return GetSystemMetrics(SM_CMONITORS);
    }

    std::vector<DISPLAYCONFIG_PATH_INFO> paths(pathCount);
    std::vector<DISPLAYCONFIG_MODE_INFO> modes(modeCount);

    result = QueryDisplayConfig(
        QDC_ONLY_ACTIVE_PATHS,
        &pathCount, paths.data(),
        &modeCount, modes.data(),
        nullptr
    );

    if (result != ERROR_SUCCESS) {
        return GetSystemMetrics(SM_CMONITORS);
    }

    // Each active path = one physical display target (source -> monitor connection)
    // In clone mode: 1 source -> 2 targets = 2 paths (both active)
    // In extend mode: 2 sources -> 2 targets = 2 paths (both active)
    // In single monitor mode: 1 source -> 1 target = 1 path
    return static_cast<int>(pathCount);
}

bool IsVirtualMachine() {
    HKEY hKey;
    bool isVM = false;
    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE, "SYSTEM\\CurrentControlSet\\Services\\Disk\\Enum", 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        char data[512];
        DWORD size = sizeof(data);
        if (RegQueryValueExA(hKey, "0", NULL, NULL, (LPBYTE)data, &size) == ERROR_SUCCESS) {
            if (strstr(data, "VBOX") != NULL ||
                strstr(data, "VMware") != NULL ||
                strstr(data, "QEMU") != NULL ||
                strstr(data, "Virtual") != NULL ||
                strstr(data, "PRL") != NULL) {
                isVM = true;
            }
        }
        RegCloseKey(hKey);
    }
    return isVM;
}

bool IsDebuggerAttached() {
    if (IsDebuggerPresent()) {
        return true;
    }
    BOOL isRemote = FALSE;
    if (CheckRemoteDebuggerPresent(GetCurrentProcess(), &isRemote) && isRemote) {
        return true;
    }
    return false;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  // Prevent screenshots and screen recording by setting window display affinity
  SetWindowDisplayAffinity(GetHandle(), WDA_MONITOR);

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  
  // Custom MethodChannel for security
  flutter::MethodChannel<flutter::EncodableValue> channel(
      flutter_controller_->engine()->messenger(), "jemypedia/security",
      &flutter::StandardMethodCodec::GetInstance());

  channel.SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getExternalDisplaysCount") {
          // GetPhysicalDisplayCount uses QueryDisplayConfig (CCD API) which correctly
          // detects monitors in clone mode, unlike the old EnumDisplayMonitors approach
          int totalPhysical = GetPhysicalDisplayCount();
          int externalCount = totalPhysical > 1 ? totalPhysical - 1 : 0;
          result->Success(flutter::EncodableValue(externalCount));
        } else if (call.method_name() == "isRooted") {
          result->Success(flutter::EncodableValue(false));
        } else if (call.method_name() == "isEmulator") {
          result->Success(flutter::EncodableValue(IsVirtualMachine()));
        } else if (call.method_name() == "isDebuggerConnected") {
          result->Success(flutter::EncodableValue(IsDebuggerAttached()));
        } else if (call.method_name() == "isBlacklistedProcessRunning") {
          result->Success(flutter::EncodableValue(IsBlacklistedProcessRunning()));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
