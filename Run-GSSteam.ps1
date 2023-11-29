# Run Steam in Gamescope
# -=-=-=-=-=-==-=-=-=-=-=-=-
# Setup socket for gamescope
# Create run directory file for startup and stats sockets
$tmpdir = if (!(Test-Path $env:XDG_RUNTIME_DIR/gamescope.XXXXXXX)) { New-Item -ItemType Directory -Path $env:XDG_RUNTIME_DIR/gamescope.XXXXXXX }

Write-Host "TMPDIR: $tmpdir"
if (Test-Path $env:XDG_RUNTIME_DIR/gamescope.XXXXXXX) {
    Write-Host "TEMP DIR EXISTS"
}
# Fail early if we don't have a proper runtime directory setup
if (-not $tmpdir -or $null -eq $env:XDG_RUNTIME_DIR) {
    Write-Error "!! Failed to find run directory in which to create stats session sockets (is \$XDG_RUNTIME_DIR set?)"
    exit 0
}


$socket = if ($null -ne $tmpdir) { Join-Path $tmpdir "startup.socket" }
$stats = if ($null -ne $tmpdir) { Join-Path $tmpdir "stats.pipe" }

Write-Host "SOCKET: $socket"
Write-Host "STATS: $stats"

$GAMESCOPE_STATS = New-Item -ItemType File -Path "$stats"
$GAMESCOPE_SOCKET = New-Item -ItemType File -Path "$socket"

Write-Host "GSOCKET: $GAMESCOPE_SOCKET"
Write-Host "GSTATS: $GAMESCOPE_STATS"

# Attempt to claim global session if we're the first one running (e.g. /run/1000/gamescope)
$lockfile = "$GAMESCOPE_STATS.lck"
if (Test-Path $lockfile) {
    $lockHandle = [System.IO.File]::Open($lockfile, 'Open', 'Write', 'None')
    if ($lockHandle) {
        Remove-Item -Path "$lockfile" -ErrorAction SilentlyContinue
        New-Item -ItemType SymbolicLink -Path "$lockfile" -Value "$tmpdir"
        Write-Host "Claimed global gamescope stats session at `"$lockfile`""
    }
    else {
        Write-Error "!! Failed to claim global gamescope stats session"
    }
}
else {
    Write-Host "creating new lock file"
    New-Item $lockfile -ItemType File
}

# =================================================================
# =================================================================
$STEAMCMD = "steam-runtime -gamepadui -f"
$REZ = "-W 3840 -H 2160 -r 60"
$GAMESCOPECMD = "/usr/bin/gamescope \
    -e \
    $REZ \
    -O *,DP-2 \
    --xwayland-count 2 \
    --hide-cursor-delay 3000 \
    --fade-out-duration 200 \
    --prefer-vk-device ${env:VULKAN_ADAPTER} \
    -R $socket -T $stats"
# --hdr-enabled

# ================================================================
# ================================================================
$STEAM_MULTPLE_XWAYLANDS = 1
$STEAM_GAMESCOPE_HDR_SUPPORTED=1
$STEAM_GAMESCOPE_VRR_SUPPORTED=1
#$WINEDLLOVERRIDES="dxgi=n"
$Env:STEAM_USE_DYNAMIC_VRS = 1
$Env:STEAM_GAMESCOPE_FANCY_SCALING_SUPPORT = 1
$Env:STEAM_GAMESCOPE_NIS_SUPPORTED = 1
$Env:STEAM_GAMESCOPE_FANCY_SCALING_SUPPORT = 1
# ----------------------------------------------
# Mango
$Env:STEAM_MANGOAPP_PRESETS_SUPPORTED = 1
$Env:STEAM_USE_MANGOAPP = 1
$mangocfg = New-TemporaryFile
$MANGOHUD_CONFIGFILE = $mangocfg
$Env:STEAM_MANGOAPP_HORIZONTAL_SUPPORTED = 1
$Env:TEAM_DISABLE_MANGOAPP_ATOM_WORKAROUND = 1
# ----------------------------------------------
# vlk
$radv_cfg = New-TemporaryFile
$RADV_FORCE_VRS_CONFIG_FILE = $radv_cfg
$Env:vk_xwayland_wait_ready ="false"
# $GTK_IM_MODULE = "Steam"


$XDG_SESSION_TYPE = "x11"
$DISPLAY = ":0"

# ==============================================================
# ==============================================================
# Atempt to fallback to a desktop session if something goes wrong too many times
$short_session_tracker_file = New-TemporaryFile
$short_session_duration = 60
$short_session_count_before_reset = 3
$SECONDS = 0

$short_session_count = Get-Content "$short_session_tracker_file" | Measure-Object -Line

if ($short_session_count.Lines -ge $short_session_count_before_reset) {
    Write-Host "gamescope-session: detected broken Steam or gamescope failure, will try to reset the session"
    New-Item -ItemType Directory -Path "${HOME}/.local/share/Steam" -ErrorAction SilentlyContinue
    # remove some caches and stateful things known to cause Steam to fail to start if corrupt
    Remove-Item -Path "${HOME}/.local/share/Steam/config/widevine" -Recurse -Force
    # extract the steam bootstrap to potentially fix the issue the next boot
    if (Test-Path "/etc/first-boot/bootstraplinux_ubuntu12_32.tar.xz") {
        Expand-Archive -Path "/etc/first-boot/bootstraplinux_ubuntu12_32.tar.xz" -DestinationPath "${HOME}/.local/share/Steam"
    }
    # change session to desktop as fallback
    steamos-session-select desktop
    # rearm
    Remove-Item -Path "$short_session_tracker_file"
    exit 1
}

# Log rotate the last session
if (Test-Path "${HOME}/.steam-tweaks.log") {
    Copy-Item -Path "${HOME}/.steam-tweaks.log" -Destination "${HOME}/.steam-tweaks.log.old"
}
if (Test-Path "${HOME}/.steam-stdout.log") {
    Copy-Item -Path "${HOME}/.steam-stdout.log" -Destination "${HOME}/.steam-stdout.log.old"
}
if (Test-Path "${HOME}/.gamescope-stdout.log") {
    Copy-Item -Path "${HOME}/.gamescope-stdout.log" -Destination "${HOME}/.gamescope-stdout.log.old"
}
if (Test-Path "${HOME}/.gamescope-cmd.log") {
    Copy-Item -Path "${HOME}/.gamescope-cmd.log" -Destination "${HOME}/.gamescope-cmd.log.old"
}
# ===================================================================
# =====================
# Start gamescope compositor, log it's output and background it
Set-Content -Path "${HOME}/.gamescope-cmd.log" -Value $env:GAMESCOPECMD
Start-Job -ScriptBlock { $GAMESCOPECMD } | Out-File "${HOME}/.gamescope-stdout.log"
$gamescope_pid = Get-Job | Where-Object { $_.Command -imatch "gamescope" } | Select-Object -ExpandProperty Id
Write-Host "PID: $gamescope_pid"
# =====================
# If we have mangohud binary start it
if (Get-Command "mangohud" -ErrorAction SilentlyContinue) {
    Start-ThreadJob { mangohud } | Out-File "${HOME}/.mangohud-stdout.log"
}
# =====================
# If we have steam_notif_daemon binary start it
# if (Get-Command "steam_notif_daemon" -ErrorAction SilentlyContinue) {
#     Start-ThreadJob { steam_notif_daemon } | Out-File "${HOME}/.steam_notif_daemon-stdout.log"
# }
# =====================
#Start Steam client
Invoke-Expression $STEAMCMD | Out-File "${HOME}/.steam-stdout.log"
# ==================================================================


if ($SECONDS -lt $short_session_duration) {
    Add-Content "$short_session_tracker_file" "steam failed"
}
else {
    Remove-Item "$short_session_tracker_file"
}
  
# When the client exits, kill gamescope nicely
Stop-Job $gamescope_pid
  
# Start a background sleep for five seconds because we don't trust it
Start-Sleep 5
  
# Catch reboot and poweroof sentinels here
if (Test-path "$env:STEAMOS_STEAM_REBOOT_SENTINEL") {
    Remove-item "$env:STEAMOS_STEAM_REBOOT_SENTINEL"
    # rearm short session tracker
    Remove-item "$short_session_tracker_file"
    Restart-computer
}
if (Test-path "$env:STEAMOS_STEAM_SHUTDOWN_SENTINEL") {
    Remove-item "$env:STEAMOS_STEAM_SHUTDOWN_SENTINEL"
    # rearm short session tracker
    Remove-item "$short_session_tracker_file"
    Stop-computer
}


# Kill all remaining jobs and warn if unexpected things are in there (should be just sleep_pid, unless gamescope failed
# to exit in time or we hit the interrupt case above)
Get-Job | ForEach-Object {
    # Warn about unexpected things
    if ($ret -ne 127 -and $_.Id -eq $gamescope_pid) {
        Write-Host "gamescope-session: gamescope timed out while exiting, killing"
    }
    elseif ($ret -ne 127 -and $_.Id -ne $sleep_pid) {
        Write-Host "gamescope-session: unexpected background pid $($_.Id) at teardown: "
        # spew some debug about it
        Get-Process -Id $_.Id | Format-List
    }

    Stop-Job -Id $_.Id -PassThru | Remove-Job
    Remove-Item "$env:XDG_RUNTIME_DIR/gamescope.XXXXXXX" -Recurse
}
