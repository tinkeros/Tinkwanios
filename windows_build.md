# Building a static `tinkwanios.exe` on Windows

`Build-TinkwaniosStatic.ps1` (in the repository root) produces a
`tinkwanios.exe` that links the C runtime helpers (libgcc, winpthreads) and
SDL2 **statically**. The finished exe only imports DLLs that ship with Windows,
so it runs on any 64-bit Windows 10/11 machine without MSYS2, MinGW or SDL2
installed.

## What you need

| Dependency | Why | Installed by the script? |
|---|---|---|
| Windows 10/11, x64 | target platform | — |
| PowerShell 5.1+ | runs the script (built into Windows) | — |
| [MSYS2](https://www.msys2.org) at `C:\msys64` | provides the MinGW-w64 toolchain | yes (winget, or the official installer) |
| `mingw-w64-x86_64-gcc` | C compiler / assembler | yes (pacman) |
| `mingw-w64-x86_64-SDL2` | SDL2, including the static `libSDL2.a` | yes (pacman) |
| `mingw-w64-x86_64-cmake` | build system | yes (pacman) |
| `mingw-w64-x86_64-ninja` | build backend | yes (pacman) |
| `mingw-w64-x86_64-binutils` | `strip`, `objdump` (dependency check) | yes (pacman) |
| Internet access | downloading the above | — |

The build uses the **MINGW64** environment (as the README requires), not
UCRT64 or CLANG64, and it puts only MSYS2's `mingw64\bin` on `PATH` while
building, so any other gcc/CMake on the machine (Visual Studio, Strawberry
Perl, a standalone CMake) is not picked up.

### Installing the dependencies by hand (optional)

The script does all of this for you. If you prefer to do it yourself, or the
automatic install fails:

1. Install MSYS2, either with winget:

   ```powershell
   winget install --id MSYS2.MSYS2 -e
   ```

   or by downloading and running the installer from <https://www.msys2.org>.
   Keep the default location `C:\msys64` (or pass `-MsysRoot` to the script).

2. Open **MSYS2 MSYS** from the Start menu and update it. Run this twice; the
   first run may close the window after updating the core packages:

   ```bash
   pacman -Syuu
   ```

3. Install the toolchain:

   ```bash
   pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-SDL2 mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-binutils
   ```

4. Run the script with `-SkipInstall` (see below).

## Running the script

From PowerShell or a Command Prompt in the repository root:

```powershell
.\Build-TinkwaniosStatic.cmd
```

The `.cmd` launchers (`Build-TinkwaniosStatic.cmd`, `Pack-Tinkwanios.cmd`)
run the matching `.ps1` with `-ExecutionPolicy Bypass` for that one process.
They work on a stock Windows install, where running `.ps1` files directly is
blocked with "running scripts is disabled on this system", and they don't
change any system setting. They accept the same options as the scripts, for
example `.\Build-TinkwaniosStatic.cmd -Clean -Bootstrap`.

If you would rather run the `.ps1` files directly, allow scripts for the
current PowerShell window only:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Build-TinkwaniosStatic.ps1
```

or permanently for your user account, with
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

The first run installs MSYS2 and the packages (a few hundred MB, several
minutes). Installing MSYS2 may show a UAC prompt. Later runs only update
packages and rebuild.

When it finishes you get:

* `tinkwanios.exe` in the repository root (stripped);
* a list of every DLL it imports, all of which must be Windows system DLLs:
  the script fails if anything else, such as `SDL2.dll` or
  `libwinpthread-1.dll`, shows up;
* `BUILD OK: ...\tinkwanios.exe`.

### Options

| Option | Effect |
|---|---|
| `-Clean` | Delete the build directory first (a full rebuild). |
| `-Bootstrap` | After building, run `tinkwanios.exe -b` to regenerate `HCRT2.BIN` with the new exe, then `tinkwanios.exe -c FreshOnce.HC`. Fails if stage 1 prints `ERR:` lines or stage 2 never prints its `Errs:` line. |
| `-SkipInstall` | Do not install or update MSYS2 or its packages; just build. |
| `-MsysRoot <dir>` | MSYS2 location (default `C:\msys64`). |
| `-BuildDir <dir>` | CMake build directory (default `build\win64-static`). |

Examples:

```powershell
.\Build-TinkwaniosStatic.cmd -Clean -Bootstrap
.\Build-TinkwaniosStatic.cmd -SkipInstall
```

By default the script builds only the exe (`-DBUILD_HCRT=OFF`) and leaves the
existing `HCRT2.BIN` alone; use `-Bootstrap` when you also want the runtime
image rebuilt.

## Two executables: `tinkwanios.exe` and `tinkwanios-cli.exe`

The script writes two files that are the **same program**, differing only in
the Subsystem field of the PE header:

| file | subsystem | use it for |
|---|---|---|
| `tinkwanios.exe` | GUI | double-click, shortcuts, the normal desktop |
| `tinkwanios-cli.exe` | console | `-c` (text REPL) and `--tui` from a terminal |

**Why `tinkwanios.exe` is GUI-subsystem.** On Windows 11 a console program
started from Explorer gets its console from the default terminal (Windows
Terminal). When that handoff stalls, which it does on some machines for
*every* console program (`cmd.exe` included), the process hangs before
`main()` runs: one thread, about 3 MB, no window, forever. Double-clicking
then looks like it does nothing, and each try leaves another hung
`tinkwanios.exe` plus an `OpenConsole.exe` behind. A GUI exe never asks for a
console, so that hang can't happen, and there is no console window next to
the SDL one either.

`tinkwanios.exe` still prints when it can. Output redirected by the parent
(a pipe or a file) is used as-is, and started from cmd or PowerShell it
attaches to that console. But a shell does not *wait* for a GUI program, so
for interactive text use run `tinkwanios-cli.exe`:

```
.	inkwanios-cli.exe -c
.	inkwanios-cli.exe --tui
```

The bootstrap (`-Bootstrap`) runs through `tinkwanios-cli.exe` for the same
reason. Don't double-click `tinkwanios-cli.exe`: it is a console program and
has the same Explorer problem described above.

`--no-console` is still accepted, so old shortcuts keep working, but it does
nothing now.

## Running it on another machine

`tinkwanios.exe` is the program, but like every tinkwanios build it boots the
HolyC runtime from files next to it. Copy at least:

* `tinkwanios.exe` (and `tinkwanios-cli.exe` if you want `-c`/`--tui`)
* `HCRT2.BIN` (and `HCRT2.DBG.Z` for symbols in backtraces)
* the `Src\` and `Doc\` directories

or the whole repository tree. To ship a single file instead, pack it (next
section).

## Packing a single self-contained exe (TinkwaniosPack)

`Pack-Tinkwanios.ps1` wraps TinkwaniosPack (`Src/TinkwaniosPack.HC`, described
in `README.MD`). It appends `HCRT2.BIN` and a RedSea RAM disk holding your app
to `tinkwanios.exe`, so the result is **one exe with nothing else to copy**.
When the packed exe starts, it mounts the RAM disk as its home drive and runs
a boot command.

You need the static `tinkwanios.exe` and an `HCRT2.BIN` from the steps above.
If the exe is missing, the pack script runs `Build-TinkwaniosStatic.ps1`
for you.

```powershell
# Pack an app; runs its Run.HC, or else <name>.HC, at startup
.\Pack-Tinkwanios.cmd -App Apps\Tetris            # -> dist\Tetris.exe

# Your own boot command (HolyC, under 144 characters)
.\Pack-Tinkwanios.cmd -BootCommand 'Beep;' -Output dist\Beep.exe

# Extra folders on the RAM disk
.\Pack-Tinkwanios.cmd -App Apps\Chess -Include Demo\Games
```

| Option | Effect |
|---|---|
| `-App <dir>` | App folder to put on the RAM disk, at the same path (`Apps\Tetris` → `/Apps/Tetris`). |
| `-BootCommand <hc>` | HolyC run at startup. The default for `-App` is `Cd("/Apps/X");#include "Run";`; with no app it is empty, which boots to the desktop. |
| `-Include <paths>` | More files or folders (repo-relative) for the RAM disk. |
| `-Output <file>` | Where to write the exe (default `dist\<app>.exe`). |
| `-NoSrcDoc` | Leave `Src\` and `Doc\` off the RAM disk. The README says packages need them for the desktop and help, so this only suits apps that do not use those. It cuts the size from ~35 MB to ~6 MB. |

How it works: the script builds a private boot drive in `build\pack\stage`
(the exe, `HCRT2.BIN`, `Src`, `Doc`, and a `Root\` folder with the RAM-disk
contents). It then runs `tinkwanios.exe -c -t .` there on a generated
`Pack.HC` that calls `TinkwaniosPack`, and checks that the output ends in the
`TinkPack` trailer. The private stage matters: `TinkwaniosPack` embeds
`/tinkwanios` before `/tinkwanios.exe`, and the repo root also holds the
Linux `tinkwanios` binary, which packing from there would embed by mistake.

Notes:

* The packed exe uses its **current directory** as `T:` and writes
  `Registry.HC.Z` there, so run it from a folder it can write to.
* A boot command that contains `"` quotes (such as `FileWrite("a.TXT",...)`)
  loses them on the way through `Pack-Tinkwanios.cmd`, because Windows
  PowerShell 5.1 strips inner quotes from arguments. For those, run
  `Set-ExecutionPolicy -Scope Process Bypass` and then call
  `.\Pack-Tinkwanios.ps1` directly, or put the command in a `.HC` file and
  pass `-BootCommand '#include "..."'` from that same window.
* To keep a long startup script, put it in a `.HC` file in the app folder
  and make the boot command `#include` it.

## Troubleshooting

* **"running scripts is disabled on this system"**: use the `.cmd`
  launcher (`.\Build-TinkwaniosStatic.cmd`, `.\Pack-Tinkwanios.cmd`), or run
  `Set-ExecutionPolicy -Scope Process Bypass` in that window first.
* **winget fails or is missing**: the script falls back to downloading
  `msys2-x86_64-latest.exe` from `repo.msys2.org`.
* **"depends on non-system DLLs"**: some library was linked dynamically.
  Make sure the build used `C:\msys64\mingw64\bin\gcc.exe` (the configure step
  prints the compiler) and retry with `-Clean`.
* **pacman reports a lock (`db.lck`)**: close any other MSYS2 windows; if none
  are running, delete `C:\msys64\var\lib\pacman\db.lck`.
