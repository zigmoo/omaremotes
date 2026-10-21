# OmaRemotes

Pick a registered machine, then Connect. OmaRemotes detects Gliff for Hyprland,
Screen Sharing / VNC for Macs, or RDP for Windows. The machine inventory is read
through `machine_registry_tool`; connection behavior belongs to the standalone
`oma_remotes_tool` Tool Forge drawer.

Mac viewing uses Remmina with fit-to-window enabled. Gliff uses the CPU video
path established on this fleet. Credentials stay in the viewer. Clipboard
sharing and Remmina telemetry are disabled. A running viewer is not proof of
authentication. Retry opens another session after a closed window; an existing
owned window is focused instead of launching duplicates.

The machine picker includes inventory entries even when their registry status
is offline; that label is registration state, not a reachability test. Machines
without a compatible screen-control service show an actionable error.

Development: DIL-3038, happy-path review on omarchy-zbook workspace 5.
This is a working prototype, pending operator interaction review and final QC.

Install the drawer alongside the existing toolbox. Symlink this checkout into
the user Omarchy plugins directory as `moo.omaremotes`, validate with
`omarchy plugin validate`, then enable with `omarchy plugin enable moo.omaremotes`.
Requires Python 3, the DIL machine registry owner, systemd user services,
Gliff, and Remmina with VNC/RDP plugins. No password is saved by OmaRemotes.
