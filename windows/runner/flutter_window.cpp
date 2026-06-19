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
#include <initguid.h>
#include <mmdeviceapi.h>
#include <functiondiscoverykeys_devpkey.h>
#include <bluetoothapis.h>
#include <devicetopology.h>

#pragma comment(lib, "Bthprops.lib")

bool IsBluetoothRadioEnabled() {
    BLUETOOTH_FIND_RADIO_PARAMS params = { sizeof(BLUETOOTH_FIND_RADIO_PARAMS) };
    HANDLE hRadio = NULL;
    HBLUETOOTH_RADIO_FIND hFind = BluetoothFindFirstRadio(&params, &hRadio);
    if (hFind != NULL) {
        CloseHandle(hRadio);
        BluetoothFindRadioClose(hFind);
        return true;
    }
    return false;
}

// Helper: convert wstring to lowercase ASCII string
static std::string WstrToLowerAscii(const std::wstring& wstr) {
    std::string s;
    s.resize(wstr.length());
    std::transform(wstr.begin(), wstr.end(), s.begin(), [](wchar_t wc) {
        return static_cast<char>(wc >= 0 && wc < 128 ? std::tolower(static_cast<int>(wc)) : '?');
    });
    return s;
}

// Blocked audio device keywords (BT, HDMI, virtual cables, remote audio)
static const std::vector<std::string> kBlockedAudioKeywords = {
    "bluetooth", "hands-free", "hdmi", "displayport",
    "nvidia", "intel(r) display", "amd high definition",
    "virtual", "cable", "obs", "stream",
    "stereo mix", "wave out", "screenaudio",
    "capture", "remote", "rdp"
};

// Check if a device name contains any blocked keyword
static bool IsBlockedByName(const std::string& name) {
    for (const auto& kw : kBlockedAudioKeywords) {
        if (name.find(kw) != std::string::npos) return true;
    }
    return false;
}

// Check if an audio endpoint is strictly a wired headphone/headset output.
// On Windows with Realtek/Intel HD Audio, when headphones are plugged in, 
// a separate endpoint with FormFactor=3 (Headphones) or FormFactor=5 (Headset)
// becomes active. When unplugged, only FormFactor=1 (Speakers) remains.
// We NEVER accept Speakers (FormFactor=1) as proof of wired headphones.
static bool IsStrictWiredHeadphoneEndpoint(UINT formFactor) {
    // 3 = Headphones, 5 = Headset (NOT Speakers=1)
    return (formFactor == 3 || formFactor == 5);
}

bool IsWiredHeadsetConnected() {
    HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    bool shouldUninitialize = SUCCEEDED(hr);

    IMMDeviceEnumerator* pEnumerator = NULL;
    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL,
                          __uuidof(IMMDeviceEnumerator), (void**)&pEnumerator);
    if (FAILED(hr) || !pEnumerator) {
        if (shouldUninitialize) CoUninitialize();
        return false;
    }

    // Enumerate ALL active render endpoints
    IMMDeviceCollection* pCollection = NULL;
    hr = pEnumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &pCollection);
    pEnumerator->Release();
    if (FAILED(hr) || !pCollection) {
        if (shouldUninitialize) CoUninitialize();
        return false;
    }

    UINT count = 0;
    pCollection->GetCount(&count);

    bool foundWiredHeadset = false;

    for (UINT i = 0; i < count && !foundWiredHeadset; i++) {
        IMMDevice* pDevice = NULL;
        if (FAILED(pCollection->Item(i, &pDevice)) || !pDevice) continue;

        IPropertyStore* pProps = NULL;
        if (SUCCEEDED(pDevice->OpenPropertyStore(STGM_READ, &pProps)) && pProps) {

            // STRICT: Only accept FormFactor = Headphones(3) or Headset(5)
            // NEVER accept Speakers(1) - speakers are ALWAYS active even with no headphone
            PROPVARIANT varFF;
            PropVariantInit(&varFF);
            bool isHeadphoneEndpoint = false;
            if (SUCCEEDED(pProps->GetValue(PKEY_AudioEndpoint_FormFactor, &varFF))) {
                isHeadphoneEndpoint = IsStrictWiredHeadphoneEndpoint(varFF.uintVal);
                PropVariantClear(&varFF);
            }

            if (isHeadphoneEndpoint) {
                // Verify it's not a blocked device (BT, HDMI, virtual, remote)
                bool blocked = false;

                PROPVARIANT varName;
                PropVariantInit(&varName);
                if (SUCCEEDED(pProps->GetValue(PKEY_Device_FriendlyName, &varName)) && varName.pwszVal) {
                    std::string name = WstrToLowerAscii(varName.pwszVal);
                    blocked = IsBlockedByName(name);
                    PropVariantClear(&varName);
                }

                if (!blocked) {
                    PROPVARIANT varEnum;
                    PropVariantInit(&varEnum);
                    if (SUCCEEDED(pProps->GetValue(PKEY_Device_EnumeratorName, &varEnum)) && varEnum.pwszVal) {
                        std::string enumName = WstrToLowerAscii(varEnum.pwszVal);
                        if (enumName.find("bthenum") != std::string::npos) blocked = true;
                        PropVariantClear(&varEnum);
                    }
                }

                if (!blocked) {
                    // An active, non-blocked Headphones/Headset endpoint found!
                    // On Realtek: this endpoint only exists when headphone is physically plugged in
                    foundWiredHeadset = true;
                }
            }

            pProps->Release();
        }
        pDevice->Release();
    }

    pCollection->Release();
    if (shouldUninitialize) CoUninitialize();
    return foundWiredHeadset;
}

bool IsBlacklistedProcessRunning() {
    DWORD aProcesses[1024], cbNeeded, cProcesses;
    unsigned int i;

    if (!EnumProcesses(aProcesses, sizeof(aProcesses), &cbNeeded)) {
        return false;
    }

    cProcesses = cbNeeded / sizeof(DWORD);
    // ONLY dedicated screen/audio recording tools — NOT communication apps or OS components
    // Communication apps (Discord, Teams, Skype) are excluded: they don't capture
    // protected audio by default and their presence should NOT block legitimate users.
    // Windows GameBar is also excluded as it is a system component.
    // ─── COMPREHENSIVE RECORDING SOFTWARE BLACKLIST ──────────────────────────
    // Matched by exact process name (lowercase .exe).
    // Does NOT include OS components, communication apps, or browsers.
    std::vector<std::string> blacklist = {

        // ── OBS & streaming ──────────────────────────────────────────────────
        "obs64.exe", "obs32.exe", "obs-browser-page.exe", "obs_browser_page.exe",
        "obsportable.exe",

        // ── Screen recorders ─────────────────────────────────────────────────
        "bandicam.exe", "bdcam.exe",
        "camtasia.exe", "camtasiastudio.exe", "camrecorder.exe",
        "fraps.exe",
        "action.exe",               // Mirillis Action!
        "xsplit.core.exe", "xsplitbroadcaster.exe", "xsplitgamecaster.exe", "xsplitvcam.exe",
        "sharex.exe",
        "snagit32.exe", "snagit64.exe", "snagiteditor.exe",
        "filmora.exe", "filmorascrn.exe", "filmora9.exe",
        "icecreamscreenrecorder.exe",
        "tinytake.exe",
        "loom.exe",
        "apowerrec.exe", "apowersoft.exe", "apowermirror.exe",
        "flashbackrecorder.exe", "flashbackconnect.exe",
        "d3dgear.exe",
        "dxtory.exe",
        "playclaw.exe",
        "nvsphelper64.exe",         // NVIDIA ShadowPlay
        "shadowplayhelper.exe",
        "nvcpluicommandserver.exe",
        "geforceexperience.exe",
        "radeonrelive.exe",         // AMD Radeon ReLive
        "radeonsoftware.exe",
        "rss.exe",                  // Radeon Software Streaming
        "hypercam.exe", "hypercam2.exe",
        "ezvid.exe",
        "debut.exe",
        "captureone.exe",
        "screencastify.exe",
        "screenpresso.exe",
        "capto.exe",
        "recordit.exe",
        "gifox.exe",
        "kazam.exe",
        "recordmydesktop.exe",
        "simplescreenrecorder.exe",
        "vokoscreen.exe", "vokoscreenng.exe",
        "greenrecorder.exe",
        "kronichscreen.exe",
        "movavi screen recorder.exe", "movaviscreenrecorder.exe",
        "movavi.exe",
        "screenrec.exe",
        "ispring free cam.exe",
        "screenflow.exe",
        "wirecast.exe",
        "vmix.exe",
        "streamlabs obs.exe", "streamlabs.exe",
        "prism live studio.exe",
        "mirillis action.exe",
        "gecata.exe",               // Gecata by Movavi
        "faststone capture.exe", "fsviewer.exe",
        "ashampoo snap.exe",
        "droplr.exe",
        "gyazo.exe",                // Gyazo GIF / video
        "lightshot.exe",
        "greenshot.exe",
        "picpick.exe",
        "screentogif.exe",

        // ── Audio recorders / DAWs ────────────────────────────────────────────
        "audacity.exe",
        "audition.exe", "adobe audition.exe",   // Adobe Audition
        "soundforge.exe", "soundforgepro.exe", "soundforgepro15.exe",
        "reaper.exe", "reaper64.exe",
        "fl.exe", "flstudio.exe",               // FL Studio
        "ableton.exe", "ableton live.exe",      // Ableton Live
        "cubase.exe", "cubasele.exe", "cubase12.exe", "cubase13.exe",
        "nuendo.exe",
        "protools.exe", "pro tools.exe",
        "studio one.exe", "studioone.exe",
        "logic pro.exe",
        "garageband.exe",
        "reason.exe",               // Reason Studios
        "bitwig studio.exe", "bitwig.exe",
        "samplitude.exe",
        "sequoia.exe",
        "presonus studio one.exe",
        "mixcraft.exe",
        "sonar.exe", "cakewalk.exe",
        "waveform.exe",             // Tracktion Waveform
        "cockos reaper.exe",
        "n-track studio.exe",
        "kdenlive.exe",
        "davinci resolve.exe", "resolve.exe",  // DaVinci Resolve (audio/video editor)
        "vegas pro.exe", "vegaspro.exe", "vegas.exe",
        "premiere pro.exe", "adobepremiere.exe",
        "finalcut.exe",
        "avisynth.exe", "virtualdub.exe", "virtualdub2.exe",
        "handbrake.exe",
        "mkv toolnix.exe", "mkvtoolnix-gui.exe",
        "total recorder.exe", "totalrecorder.exe",
        "mp3mymp3.exe",
        "wavosaur.exe",
        "ocenaudio.exe",
        "goldwave.exe",
        "nero wave editor.exe",
        "wavepad.exe",
        "adobe soundbooth.exe",
        "kristal audio engine.exe",
        "traverse.exe",
        "audio recorder.exe",
        "apowersoft audio recorder.exe",
        "voice recorder.exe",

        // ── Video capture / streaming tools ──────────────────────────────────
        "zoom.exe", "zoomopener.exe",           // Zoom (can record meetings)
        "webex.exe", "ciscowebex.exe",          // Cisco Webex
        "gotomeeting.exe",
        "bigbluebutton.exe",
        "jitsi meet.exe",
        "kaltura capture.exe",
        "panopto recorder.exe", "panoptorecorder.exe",
        "camstudio.exe",
        "screencastomatic.exe",
        "screencastify.exe",
        "loom-recorder.exe",
        "clipchamp.exe",
        "clip studio.exe",
        "acethinker.exe",
        "recordpad.exe",
        "screenrecorderapp.exe",
        "icecream screen recorder.exe",

        // ── Remote desktop / mirroring (can capture audio/screen) ────────────
        "anydesk.exe",
        "teamviewer.exe", "teamviewer_desktop.exe",
        "rdpclip.exe",              // RDP clipboard (virtual channel for audio)
        "mstsc.exe",                // Microsoft RDP (external session)
        "parsec.exe",
        "rustdesk.exe",
        "vnc.exe", "vncviewer.exe", "vncserver.exe",
        "realvnc.exe",
        "ultravnc.exe",
        "tightvnc.exe",
        "splashtop.exe",
        "logmein.exe",

        // ── Virtual audio / loopback cables ──────────────────────────────────
        "voicemeeter.exe", "voicemeeterpro.exe", "voicemeeterbanana.exe", "voicemeeter8.exe",
        "vbcable.exe",
        "blackhole.exe",
        "virtual audio cable.exe", "vac.exe",
        "soundflower.exe",
        "stealth audio capture.exe",
        "audio router.exe",
        "equalizerapo.exe",
        "peacock.exe",              // Peace APO GUI
        "reastream.exe",
        "jack.exe", "jackd.exe",    // JACK Audio
        "asio4all.exe",

        // ── Network / protocol-level stream grabbers ──────────────────────────
        "streamlink.exe",
        "yt-dlp.exe", "youtube-dl.exe",
        "ffmpeg.exe", "ffprobe.exe",
        "vlc.exe",                  // VLC (can record streams)
        "mpc-hc.exe", "mpc-hc64.exe", "mpc-be.exe", "mpc-be64.exe",
        "potplayer.exe", "potplayermini.exe", "potplayermini64.exe",
        "kmplayer.exe",
        "smplayer.exe",
        "mpv.exe",
        "mediainfo.exe",
        "wireshark.exe",            // Network packet capture
        "fiddler.exe", "fiddler everywhere.exe",
        "charles.exe",              // HTTP proxy
        "mitmproxy.exe",
        "burpsuite.exe",
        "hxd.exe",
        "x64dbg.exe", "x32dbg.exe",
        "ollydbg.exe",
        "cheatengine.exe", "cheatengine-x86_64.exe",
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
      [hwnd = GetHandle()](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getExternalDisplaysCount") {
          int totalPhysical = GetPhysicalDisplayCount();
          int externalCount = totalPhysical > 1 ? totalPhysical - 1 : 0;
          result->Success(flutter::EncodableValue(externalCount));
        } else if (call.method_name() == "isRooted") {
          result->Success(flutter::EncodableValue(false));
        } else if (call.method_name() == "isEmulator") {
          result->Success(flutter::EncodableValue(IsVirtualMachine()));
        } else if (call.method_name() == "isScreenRecording") {
          result->Success(flutter::EncodableValue(IsBlacklistedProcessRunning()));
        } else if (call.method_name() == "isDebuggerConnected") {
          result->Success(flutter::EncodableValue(IsDebuggerAttached()));
        } else if (call.method_name() == "isBlacklistedProcessRunning") {
          result->Success(flutter::EncodableValue(IsBlacklistedProcessRunning()));
        } else if (call.method_name() == "isBluetoothEnabled") {
          result->Success(flutter::EncodableValue(IsBluetoothRadioEnabled()));
        } else if (call.method_name() == "isWiredHeadsetOn") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "stopApp") {
          // Close the application window immediately
          result->Success(flutter::EncodableValue(true));
          PostMessage(hwnd, WM_CLOSE, 0, 0);
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
