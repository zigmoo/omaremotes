# OmaRemotes

Pick a registered machine, then Connect. Automatic routing uses a saved native
iShareScreen or browser noVNC-ARD profile for configured Macs. Legacy Gliff for
Hyprland, Remmina VNC for Macs, and Remmina RDP for Windows remain available.
The machine inventory is read through `machine_registry_tool`; connection
behavior belongs to the standalone `oma_remotes_tool` Tool Forge drawer.

The picker keeps its plain-PHP helper running between requests. The drawer's
`MacViewer.php` supervises the selected Mac adapter, while the plugin displays
connection progress and session state. An existing owned window is focused on
repeat Connect. Reconnect closes that session and starts a new one; Close session
stops the selected tool-owned session. A running process or rendered frame does
not establish that the desktop image is correct or usable.

The machine picker uses Tailscale's live Online flag for its TS online/offline
indicator and refreshes every 15 seconds while visible. Missing peers or
unavailable Tailscale stay unknown. Hostname and MagicDNS matching is
case-insensitive; inventory status is
not a reachability signal. Connect separately checks the screen-control service.
All inventory entries remain searchable. Machines without a compatible service
show an actionable error.

Mac profiles and client installation paths belong to `setting_tool` under
`omaRemotesRuntime`. Each profile selects `isharescreen` or `novnc-ard`, a
credential profile, and an opt-in `clipboard` flag; native profiles can select
the codec, and browser profiles supply loopback relay/debug ports. The default
native codec is AVC. `omaRemotesAuthAttemptTimeoutSeconds` bounds authentication
to at most 15 seconds, and `omaRemotesLoginMaxAttempts` caps a Connect run at
three attempts. Each adapter submits credentials once; recognized failures may
be retried by the supervisor within that cap. An explicit Reconnect starts a
fresh run. There is no automatic viewer/codec fallback or post-success reconnect.

Confirmed account/item mappings are resolved through `appleScreenRuntime`,
`apple_screen_tool` and `token_tool` when connecting. The protected credential
cache remains owned by those tools. Passwords reach the Mac adapter through
stdin, never command-line arguments, plugin settings, session receipts or
metrics. The legacy Remmina route retains manual login and disables password
storage. Gliff uses CPU video; legacy clipboard sharing and Remmina telemetry
remain disabled.

Mac text clipboard sharing defaults off and must be enabled per profile. When
enabled, it can read and replace text on both endpoints. Session receipts and
metrics contain operational metadata only, never clipboard contents, screen
pixels or screenshots. Audio, recording and curtain mode are not enabled by the
managed Mac routes.

The managed POC observations on 2026-10-22 are:

| Target | Selected route | Observed result |
| --- | --- | --- |
| Small M1 (`moosacrem1`, macOS 26.5.1) | Native iShareScreen, AVC | Connected; synthetic text clipboard passed in both directions. |
| ProMax (`moosacrem1promax`, macOS 27.0.1) | Browser noVNC-ARD, standard TCP | Connected and rendered; ZBook-to-Mac text clipboard passed. Mac-to-ZBook clipboard timed out, including after an explicit fetch. Inbound clipboard remains unresolved. |

HEVC is deferred after visibly corrupted output; draw counts alone did not prove
image correctness. These results do not isolate the ProMax clipboard failure to
the server or browser client. They are scoped happy-path evidence, not general
platform certification. No QC suite was run for the operator-directed POC.
The existing `tests/HappyPath.qml` still expects the legacy `viewer_open` state
and is not validation evidence for the managed Mac path's `connected` state.
The prototype also reads its English catalog locally because the deployed
ZBook shell lacks `Commons.Translations`; native live-language integration is
unfinished. Development began in DIL-3038; current implementation and evidence
are tracked in [DIL-3044](https://framemoowork.jay-frog.ts.net:8443/knowledge?item=X3NoYXJlZC9kb21haW5zL3BlcnNvbmFsL3Rhc2tzL2FjdGl2ZS9ESUwtMzA0NC5tZA&view=document).

Install the drawer alongside the existing toolbox and provision the selected
viewer before enabling the plugin. Symlink this checkout into the user Omarchy
plugins directory as `moo.omaremotes`, then enable it with
`omarchy plugin enable moo.omaremotes`. The runtime does not install dependencies.

- Common: Omarchy/Quickshell, plain PHP CLI, DIL owner tools, Tailscale, Hyprland
  and systemd user services.
- Native Mac: the configured iShareScreen checkout and Python environment with
  PyAV/FFmpeg, NumPy, wgpu, rendercanvas, GLFW and crypto dependencies, plus a
  working GPU driver. Text clipboard additionally needs its OS backend; Wayland
  uses `wl-copy` and `wl-paste`.
- Browser Mac: the configured noVNC-ARD checkout with the POC clipboard guards
  and relay CSP changes, Node.js and a Chromium-compatible browser.
- Legacy routes: Gliff/OpenSSH or Remmina, with libvncserver for VNC and freerdp
  for RDP.
