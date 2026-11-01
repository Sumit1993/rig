#!/bin/bash
# wake.sh: a wake-up for an unattended run that outlives any one session or harness.
# The OS scheduler (Task Scheduler, launchd, a systemd user timer) runs `wake.sh tick`, which
# starts a headless harness turn on the plan file. autopilot §0, arm the wake-up.
#
#   wake.sh arm <name> <minutes> <plan-file> [--harness claude|codex] [--session <id>] [--cwd <dir>]
#   wake.sh tick <name>        run by the scheduler: one turn under a lock, stamped
#   wake.sh disarm <name>      remove the OS job and the state directory
#   wake.sh status <name>
# --dry-run on arm or disarm prints the OS config and commands instead of applying them;
# --os windows|macos|linux overrides detection. RIG_WAKE_RUNNER replaces the harness command (tests).
set -u
STATE_ROOT="${RIG_WAKE_STATE:-$HOME/ai-context/state/wake}"
SELF=$(realpath -m "$0")
die() { echo "wake: $*" >&2; exit 2; }

detect_os() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    Darwin) echo macos ;;
    Linux) if command -v schtasks.exe >/dev/null 2>&1; then echo windows; else echo linux; fi ;;
    *) echo unknown ;;
  esac
}

# The command a scheduler runs: a login shell, so the harness CLIs are on PATH.
tick_cmd() { printf "'%s' tick '%s'" "$SELF" "$1"; }

arm_windows() { # name minutes
  local tn="rig-wake-$1" xml bash_exe args
  if grep -qi microsoft /proc/version 2>/dev/null; then
    bash_exe='C:\Windows\System32\wsl.exe'; args="-e bash -lc &quot;$(tick_cmd "$1")&quot;"
  else
    bash_exe=$(cygpath -w "$(command -v bash)"); args="-lc &quot;$(tick_cmd "$1")&quot;"
  fi
  xml="<?xml version=\"1.0\" encoding=\"UTF-16\"?>
<Task version=\"1.4\" xmlns=\"http://schemas.microsoft.com/windows/2004/02/mit/task\">
  <Triggers><TimeTrigger><StartBoundary>$(date +%Y-%m-%dT%H:%M:%S)</StartBoundary>
    <Repetition><Interval>PT$2M</Interval></Repetition></TimeTrigger></Triggers>
  <Settings>
    <WakeToRun>true</WakeToRun><StartWhenAvailable>true</StartWhenAvailable>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT2H</ExecutionTimeLimit>
  </Settings>
  <Actions><Exec><Command>$bash_exe</Command><Arguments>$args</Arguments></Exec></Actions>
</Task>"
  if [ "$DRY" = 1 ]; then printf '%s\n' "$xml"; echo "schtasks /create /tn $tn /xml <file> /f"; return; fi
  local f; f="$DIR/task.xml"
  { printf '\377\376'; printf '%s' "$xml" | iconv -f UTF-8 -t UTF-16LE; } > "$f" || die "iconv failed"
  MSYS_NO_PATHCONV=1 schtasks.exe /create /tn "$tn" /xml "$(cygpath -w "$f" 2>/dev/null || wslpath -w "$f")" /f >/dev/null || die "schtasks /create failed"
}

arm_macos() {
  local label="com.rig.wake.$1" plist="$HOME/Library/LaunchAgents/com.rig.wake.$1.plist" body
  body="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>-lc</string><string>$(tick_cmd "$1")</string></array>
  <key>StartInterval</key><integer>$(($2 * 60))</integer>
</dict></plist>"
  if [ "$DRY" = 1 ]; then printf '%s\n' "$body"; echo "launchctl bootstrap gui/\$(id -u) $plist"; return; fi
  mkdir -p "$(dirname "$plist")" && printf '%s\n' "$body" > "$plist"
  launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || launchctl load "$plist" || die "launchctl failed"
}

arm_linux() {
  local u="rig-wake-$1" d="$HOME/.config/systemd/user" cal svc tmr
  if [ "$2" -lt 60 ]; then cal="*:0/$2"; else cal="0/$(($2 / 60)):00"; fi
  svc="[Unit]
Description=rig wake-up $1
[Service]
Type=oneshot
ExecStart=/bin/bash -lc \"$(tick_cmd "$1")\""
  tmr="[Unit]
Description=rig wake-up $1
[Timer]
OnCalendar=$cal
Persistent=true
WakeSystem=true
[Install]
WantedBy=timers.target"
  if [ "$DRY" = 1 ]; then printf '%s\n---\n%s\n' "$svc" "$tmr"; echo "systemctl --user enable --now $u.timer"; return; fi
  mkdir -p "$d" && printf '%s\n' "$svc" > "$d/$u.service" && printf '%s\n' "$tmr" > "$d/$u.timer"
  systemctl --user daemon-reload && systemctl --user enable --now "$u.timer" || die "systemctl failed"
  loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q yes || echo "wake: run 'loginctl enable-linger $USER' so ticks fire while logged out" >&2
}

disarm_os() {
  case "$OS" in
    windows) [ "$DRY" = 1 ] && { echo "schtasks /delete /tn rig-wake-$1 /f"; return; }
             MSYS_NO_PATHCONV=1 schtasks.exe /delete /tn "rig-wake-$1" /f >/dev/null 2>&1 ;;
    macos) [ "$DRY" = 1 ] && { echo "launchctl bootout gui/\$(id -u)/com.rig.wake.$1"; return; }
           launchctl bootout "gui/$(id -u)/com.rig.wake.$1" 2>/dev/null; rm -f "$HOME/Library/LaunchAgents/com.rig.wake.$1.plist" ;;
    linux) [ "$DRY" = 1 ] && { echo "systemctl --user disable --now rig-wake-$1.timer"; return; }
           systemctl --user disable --now "rig-wake-$1.timer" 2>/dev/null
           rm -f "$HOME/.config/systemd/user/rig-wake-$1".{service,timer} ;;
  esac
}

keep_awake_hint() {
  case "$OS" in
    windows) echo "wake: a sleeping PC wakes only if wake timers are on; keep it awake plugged in (PowerToys Awake, or display-off Never)" ;;
    macos) echo "wake: keep the Mac awake with 'caffeinate -s' on AC power" ;;
    linux) echo "wake: keep the machine awake with 'systemd-inhibit --what=sleep <cmd>'" ;;
  esac
}

tick() {
  [ -f "$DIR/plan" ] || die "no wake-up named $NAME"
  mkdir "$DIR/lock" 2>/dev/null || { echo "$(date -u +%FT%TZ) skipped: previous tick still running" >> "$DIR/log"; exit 0; }
  trap 'rmdir "$DIR/lock"' EXIT
  local plan harness session cwd last prompt
  plan=$(cat "$DIR/plan"); harness=$(cat "$DIR/harness"); session=$(cat "$DIR/session" 2>/dev/null); cwd=$(cat "$DIR/cwd")
  last=$(cat "$DIR/last" 2>/dev/null || echo never)
  prompt="Wake-up tick (rig autopilot). Last tick: $last. Read $plan, check live state, act on everything that fell due since the last tick, append one line to its log. Nothing due: end without output."
  date -u +%FT%TZ > "$DIR/last"
  cd "$cwd" || die "cwd $cwd missing"
  {
    echo "$(date -u +%FT%TZ) tick harness=$harness"
    if [ -n "${RIG_WAKE_RUNNER:-}" ]; then "$RIG_WAKE_RUNNER" "$harness" "$session" "$prompt"
    else case "$harness" in
      claude) claude -p "$prompt" ${session:+--resume "$session"} ;;
      codex) if [ -n "$session" ]; then codex exec resume "$session" "$prompt"; else codex exec "$prompt"; fi ;;
    esac; fi
    echo "TICK_DONE rc=$?"
  } >> "$DIR/log" 2>&1
}

CMD="${1:-}"; NAME="${2:-}"; DRY=0; OS=$(detect_os)
[ -n "$CMD" ] && [ -n "$NAME" ] || die "usage: wake.sh arm|tick|disarm|status <name> ..."
case "$NAME" in *[!A-Za-z0-9_-]*) die "name takes letters, digits, - and _ only" ;; esac
DIR="$STATE_ROOT/$NAME"
shift 2
case "$CMD" in
  arm)
    MIN="${1:-}"; PLAN="${2:-}"; shift 2 2>/dev/null || die "arm needs <minutes> <plan-file>"
    HARNESS=claude; SESSION=""; CWD=$(pwd)
    while [ $# -gt 0 ]; do case "$1" in
      --harness) HARNESS="$2"; shift ;; --session) SESSION="$2"; shift ;; --cwd) CWD="$2"; shift ;;
      --dry-run) DRY=1 ;; --os) OS="$2"; shift ;; *) die "unknown flag $1" ;; esac; shift; done
    case "$MIN" in ''|*[!0-9]*) die "minutes must be a whole number" ;; esac
    [ "$MIN" -ge 5 ] || die "minutes must be 5 or more"
    case "$HARNESS" in claude|codex) ;; *) die "harness is claude or codex" ;; esac
    [ "$DRY" = 1 ] || { mkdir -p "$DIR" && echo "$(realpath -m "$PLAN")" > "$DIR/plan" && echo "$HARNESS" > "$DIR/harness" \
      && printf '%s' "$SESSION" > "$DIR/session" && realpath -m "$CWD" > "$DIR/cwd" || die "cannot write $DIR"; }
    case "$OS" in windows) arm_windows "$NAME" "$MIN" ;; macos) arm_macos "$NAME" "$MIN" ;; linux) arm_linux "$NAME" "$MIN" ;;
      *) die "no scheduler known for $(uname -s)" ;; esac
    [ "$DRY" = 1 ] || { echo "armed $NAME: every $MIN min on $OS, $HARNESS${SESSION:+ session $SESSION}, log $DIR/log"; keep_awake_hint >&2; } ;;
  tick) tick ;;
  disarm)
    while [ $# -gt 0 ]; do case "$1" in --dry-run) DRY=1 ;; --os) OS="$2"; shift ;; *) die "unknown flag $1" ;; esac; shift; done
    disarm_os "$NAME"; [ "$DRY" = 1 ] || { rm -rf "$DIR"; echo "disarmed $NAME"; } ;;
  status)
    [ -f "$DIR/plan" ] || { echo "$NAME: not armed"; exit 1; }
    echo "$NAME: $(cat "$DIR/harness") plan=$(cat "$DIR/plan") last=$(cat "$DIR/last" 2>/dev/null || echo never)"
    tail -n 3 "$DIR/log" 2>/dev/null ;;
  *) die "unknown command $CMD" ;;
esac
