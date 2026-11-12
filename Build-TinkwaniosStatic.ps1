<#
.SYNOPSIS
  Build a fully static tinkwanios.exe for Windows (x86_64).

.DESCRIPTION
  1. Installs MSYS2 (to C:\msys64 by default) if it is missing, via winget,
     falling back to the official self-extracting installer.
  2. Updates MSYS2 and installs the MINGW64 toolchain the README asks for:
     gcc, SDL2 (which ships libSDL2.a), cmake and ninja.
  3. Configures and builds with the MINGW64 toolchain into build\win64-static,
     linking libgcc, winpthreads and SDL2 statically (-static). The result is
     tinkwanios.exe in the repository root.
  4. Checks the exe's import table: every DLL it needs must be one that ships
     with Windows, so it runs on any Windows 10/11 x64 machine without MSYS2.

  The exe still needs the runtime image HCRT2.BIN (and the Src/Doc trees) next
  to it, exactly like any other tinkwanios build. Pass -Bootstrap to rebuild
  HCRT2.BIN with the new exe after compiling it.

.PARAMETER MsysRoot
  Where MSYS2 is (or will be) installed. Default C:\msys64.

.PARAMETER BuildDir
  CMake build directory. Default <repo>\build\win64-static.

.PARAMETER Clean
  Delete the build directory before configuring.

.PARAMETER Bootstrap
  After building the exe, run "tinkwanios.exe -b" to regenerate HCRT2.BIN.

.PARAMETER SkipInstall
  Do not install or update MSYS2 packages; just build.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Build-TinkwaniosStatic.ps1
.EXAMPLE
  .\Build-TinkwaniosStatic.ps1 -Clean -Bootstrap
#>
[CmdletBinding()]
param(
  [string]$MsysRoot  = 'C:\msys64',
  [string]$BuildDir  = '',
  [switch]$Clean,
  [switch]$Bootstrap,
  [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot
if (-not $BuildDir) { $BuildDir = Join-Path $RepoRoot 'build\win64-static' }

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

$MsysBash  = Join-Path $MsysRoot 'usr\bin\bash.exe'
$Mingw64   = Join-Path $MsysRoot 'mingw64\bin'

# Run a command in an MSYS2 login shell. MSYSTEM=MSYS is right for pacman.
function Invoke-Msys([string]$cmd) {
  $env:MSYSTEM = 'MSYS'
  $env:CHERE_INVOKING = '1'
  & $MsysBash -lc $cmd
  if ($LASTEXITCODE -ne 0) { Fail "MSYS2 command failed ($LASTEXITCODE): $cmd" }
}

# ---------------------------------------------------------------- MSYS2 ----
if (-not (Test-Path $MsysBash)) {
  if ($SkipInstall) { Fail "MSYS2 not found at $MsysRoot and -SkipInstall was given." }
  Step "Installing MSYS2 to $MsysRoot"
  $installed = $false
  if ((Get-Command winget -ErrorAction SilentlyContinue) -and $MsysRoot -eq 'C:\msys64') {
    & winget install --id MSYS2.MSYS2 -e --silent --accept-package-agreements --accept-source-agreements
    $installed = Test-Path $MsysBash
  }
  if (-not $installed) {
    Write-Host 'winget unavailable or failed; using the MSYS2 installer from repo.msys2.org'
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("msys2-" + [guid]::NewGuid())
    New-Item -ItemType Directory $tmp | Out-Null
    $exe = Join-Path $tmp 'msys2-x86_64-latest.exe'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest 'https://repo.msys2.org/distrib/msys2-x86_64-latest.exe' -OutFile $exe -UseBasicParsing
    & $exe in --confirm-command --accept-messages --root ($MsysRoot -replace '\\','/')
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
  if (-not (Test-Path $MsysBash)) { Fail "MSYS2 installation did not produce $MsysBash" }
  # First login initialises the keyring and home directory.
  Invoke-Msys 'true'
}

if (-not $SkipInstall) {
  Step 'Updating MSYS2 (core first, then everything)'
  # The first -Syuu may update the runtime itself and end the shell; run twice.
  $env:MSYSTEM = 'MSYS'
  & $MsysBash -lc 'pacman -Syuu --noconfirm' | Out-Host
  Invoke-Msys 'pacman -Syuu --noconfirm'

  Step 'Installing MINGW64 toolchain: gcc, SDL2, cmake, ninja'
  Invoke-Msys ('pacman -S --needed --noconfirm ' +
    'mingw-w64-x86_64-gcc mingw-w64-x86_64-SDL2 ' +
    'mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-binutils')
}

foreach ($t in 'gcc.exe','cmake.exe','ninja.exe','objdump.exe') {
  if (-not (Test-Path (Join-Path $Mingw64 $t))) { Fail "$t missing from $Mingw64 (run without -SkipInstall)" }
}
if (-not (Test-Path (Join-Path $MsysRoot 'mingw64\lib\libSDL2.a'))) {
  Fail 'Static SDL2 (libSDL2.a) not found; install mingw-w64-x86_64-SDL2.'
}

# ---------------------------------------------------------------- build ----
# Only the MINGW64 toolchain on PATH, so no other gcc/cmake can leak in.
$env:PATH    = "$Mingw64;$MsysRoot\usr\bin;$env:SystemRoot\System32;$env:SystemRoot"
$env:MSYSTEM = 'MINGW64'
$cmake = Join-Path $Mingw64 'cmake.exe'

if ($Clean -and (Test-Path $BuildDir)) {
  Step "Removing $BuildDir"
  Remove-Item $BuildDir -Recurse -Force
}

Step "Configuring ($BuildDir)"
$staticFlags = '-static -static-libgcc'
& $cmake -S $RepoRoot -B $BuildDir -G Ninja `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_C_COMPILER=gcc `
  -DBUILD_HCRT=OFF `
  "-DCMAKE_EXE_LINKER_FLAGS=$staticFlags" `
  "-DSDL2_DIR=$($MsysRoot -replace '\\','/')/mingw64/lib/cmake/SDL2"
if ($LASTEXITCODE -ne 0) { Fail 'CMake configure failed' }

Step 'Building tinkwanios.exe'
& $cmake --build $BuildDir --target tinkwanios -j ([Environment]::ProcessorCount)
if ($LASTEXITCODE -ne 0) { Fail 'Build failed' }

$Exe = Join-Path $RepoRoot 'tinkwanios.exe'
if (-not (Test-Path $Exe)) { Fail "Build finished but $Exe was not produced" }

& (Join-Path $Mingw64 'strip.exe') --strip-unneeded $Exe

# tinkwanios.exe is GUI-subsystem so a double-click never waits on a console.
# tinkwanios-cli.exe is the identical binary with the PE header's Subsystem
# field set to 3 (console): use it for -c / --tui from a terminal, so the
# shell waits for it and it owns the console's input.
$CliExe = Join-Path $RepoRoot 'tinkwanios-cli.exe'
$bytes  = [IO.File]::ReadAllBytes($Exe)
$peOff  = [BitConverter]::ToInt32($bytes, 0x3C)
$subOff = $peOff + 24 + 68   # PE sig + COFF header, then OptionalHeader.Subsystem
if ([BitConverter]::ToUInt16($bytes, $subOff) -ne 2) { Fail 'tinkwanios.exe is not a GUI-subsystem exe (was -mwindows dropped?)' }
$bytes[$subOff] = 3; $bytes[$subOff + 1] = 0
[IO.File]::WriteAllBytes($CliExe, $bytes)
Write-Host "Wrote $CliExe (console subsystem)"

# ------------------------------------------------------------ verify ------
Step 'Checking DLL imports'
# DLLs that are part of every Windows 10/11 x64 install.
$systemDlls = @(
  'kernel32.dll','user32.dll','gdi32.dll','advapi32.dll','shell32.dll',
  'ole32.dll','oleaut32.dll','imm32.dll','winmm.dll','version.dll',
  'setupapi.dll','shlwapi.dll','ws2_32.dll','ntdll.dll','bcrypt.dll',
  'msvcrt.dll','comdlg32.dll','cfgmgr32.dll','hid.dll','dinput8.dll',
  'xinput1_4.dll','dwmapi.dll','uxtheme.dll','rpcrt4.dll','crypt32.dll',
  'bcryptprimitives.dll','userenv.dll','secur32.dll','iphlpapi.dll',
  'mswsock.dll','dxgi.dll','d3d11.dll','d3d9.dll','opengl32.dll',
  'combase.dll','powrprof.dll'
)
$imports = & (Join-Path $Mingw64 'objdump.exe') -p $Exe |
  Select-String 'DLL Name:\s*(\S+)' |
  ForEach-Object { $_.Matches[0].Groups[1].Value.ToLower() } |
  Sort-Object -Unique
$imports | ForEach-Object { Write-Host "  $_" }
$foreign = $imports | Where-Object { ($systemDlls -notcontains $_) -and ($_ -notlike 'api-ms-win-*') }
if ($foreign) { Fail ("tinkwanios.exe depends on non-system DLLs: " + ($foreign -join ', ')) }
Write-Host 'All imports are Windows system DLLs.' -ForegroundColor Green

# --------------------------------------------------------- bootstrap ------
if ($Bootstrap) {
  Step 'Bootstrapping HCRT2.BIN (tinkwanios.exe -b)'
  Push-Location $RepoRoot
  try {
    $log = & $CliExe -b 2>&1 | Tee-Object -Variable out | Out-String
    $out | Out-Host
    if ($log -match '(?m)^ERR:') { Fail 'Bootstrap stage 1 reported ERR: lines' }
    if ($log -notmatch '(?m)^Errs:') { Fail 'Bootstrap never reached stage 2 (no Errs: line)' }
    & $CliExe -c FreshOnce.HC | Out-Host
  } finally { Pop-Location }
}

$size = '{0:N1} MB' -f ((Get-Item $Exe).Length / 1MB)
Write-Host "`nBUILD OK: $Exe ($size)" -ForegroundColor Green
Write-Host 'Ship it with HCRT2.BIN, Src\ and Doc\, or make one exe with .\Pack-Tinkwanios.ps1.'
