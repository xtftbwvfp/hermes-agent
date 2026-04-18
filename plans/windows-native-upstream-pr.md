# Windows Native Compatibility PR Draft

## Suggested PR title

Enable native Windows maintenance path and fix core Windows runtime issues

## Why

Hermes currently documents WSL2 as the supported Windows path, but the codebase already contains substantial Windows support. This patch set closes several practical gaps that blocked native Windows use in real deployments:

- native Windows shells could accidentally route into WSL via `C:\Windows\System32\bash.exe`
- UTF-8/GBK mismatches caused crashes or silent config/runtime failures on Chinese Windows installs
- profile and gateway status commands disagreed when the gateway was running as a Windows service
- process liveness and termination logic still assumed POSIX behavior in several paths
- profile aliases were still Unix-shaped even on Windows

## What changed

### Shell and process behavior

- prefer Git Bash on Windows and explicitly avoid `System32\bash.exe` as a native shell backend
- reuse Windows-safe PID existence and termination helpers in profile and process registry code
- improve Windows service detection for `hermes gateway status`
- make browser orphan cleanup use Windows-safe process handling

### Encoding and file I/O

- force UTF-8 stdio configuration in the CLI on Windows
- read and write gateway/profile/auth/update state files with explicit UTF-8
- make cron config loading UTF-8-safe
- fix update prompt/response files on Telegram/Discord/gateway flows

### Profile UX

- create `.cmd` profile aliases on Windows instead of Unix shell wrappers
- point `doctor`, `profile show`, and alias creation logic at the Windows wrapper path
- make `profile show` and `profile list` read `gateway_state.json` so Windows-service gateways are shown as running

### Installer

- use `npm.cmd` in the PowerShell installer to avoid `npm.ps1` execution-policy failures

## Files most relevant to review

- `tools/environments/local.py`
- `hermes_cli/main.py`
- `hermes_cli/profiles.py`
- `hermes_cli/gateway.py`
- `gateway/status.py`
- `gateway/run.py`
- `tools/process_registry.py`
- `tools/browser_tool.py`
- `cron/scheduler.py`
- `hermes_cli/auth.py`
- `hermes_cli/doctor.py`
- `scripts/install.ps1`

## Manual verification performed on Windows

Run from the Windows-native maintenance branch:

```powershell
python -m hermes_cli.main --profile winfix doctor
python -m hermes_cli.main --profile winfix profile list
python -m hermes_cli.main --profile winfix gateway status
python -m hermes_cli.main --profile winfix chat -q "Reply with ok only"
```

Observed results:

- `doctor` completed successfully
- `profile list` showed the active Windows profile as `running`
- `gateway status` detected the live Windows service correctly
- `chat -q` returned `ok`
- the existing Windows service `HermesWinfix` continued to run normally

## Recommended review strategy

This patch set is valuable but broad. The cleanest upstreaming path is likely:

1. merge the low-risk UTF-8 and Windows process-liveness fixes first
2. merge the Windows alias/service-status UX changes next
3. merge installer and shell-selection changes after that

If desired, the current `windows-native` branch can be split into smaller PRs along those boundaries.

## Notes for future syncs

The local maintenance workflow for this branch is:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows-sync-upstream.ps1
```

That script fetches `upstream/main`, merges it into `windows-native`, and reruns a Windows smoke-test set.
