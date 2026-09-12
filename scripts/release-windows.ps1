param(
    [string]$MsixVersion = "",
    [switch]$SkipTests,
    [switch]$SkipGitCleanCheck
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Assert-LastExitCode {
    param([string]$StepName)

    if ($LASTEXITCODE -ne 0) {
        throw "$StepName a échoué avec le code $LASTEXITCODE."
    }
}

# ------------------------------------------------------------
# 0. Localisation du projet
# ------------------------------------------------------------

if ($PSScriptRoot) {
    $ScriptDir = $PSScriptRoot
    $ProjectRoot = Split-Path -Parent $ScriptDir
}
else {
    $ProjectRoot = (Get-Location).Path
}

Set-Location $ProjectRoot

Write-Step "FocusDay Windows Release"

Write-Host "Projet : $ProjectRoot"
Write-Host "Date   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# ------------------------------------------------------------
# 1. Vérification de l'environnement
# ------------------------------------------------------------

Write-Step "1/9 - Vérification de l'environnement"

$requiredCommands = @(
    "git",
    "flutter",
    "dart"
)

foreach ($command in $requiredCommands) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Commande requise introuvable : $command"
    }

    Write-Host "[OK] $command"
}

Write-Host ""
flutter --version
Assert-LastExitCode "flutter --version"

# ------------------------------------------------------------
# 2. Vérification Git
# ------------------------------------------------------------

Write-Step "2/9 - Vérification Git"

$branch = git branch --show-current
Assert-LastExitCode "git branch --show-current"

Write-Host "Branche : $branch"

if ($branch -ne "main") {
    throw "La release Windows doit être créée depuis la branche main. Branche actuelle : $branch"
}

git fetch origin
Assert-LastExitCode "git fetch origin"

$localCommit = git rev-parse HEAD
Assert-LastExitCode "git rev-parse HEAD"

$remoteCommit = git rev-parse origin/main
Assert-LastExitCode "git rev-parse origin/main"

Write-Host "HEAD        : $localCommit"
Write-Host "origin/main : $remoteCommit"

if ($localCommit -ne $remoteCommit) {
    Write-Warning "HEAD et origin/main ne sont pas identiques."
    Write-Warning "Vérifiez que les commits voulus sont bien poussés avant publication."
}

if (-not $SkipGitCleanCheck) {
    $gitStatus = git status --porcelain
    Assert-LastExitCode "git status"

    if ($gitStatus) {
        Write-Host ""
        Write-Host "Fichiers modifiés :"
        git status --short

        throw "Le dépôt Git n'est pas propre. Committez ou restaurez les modifications avant la release."
    }
}

Write-Host "[OK] État Git validé."

# ------------------------------------------------------------
# 3. Vérification / mise à jour de la version MSIX
# ------------------------------------------------------------

Write-Step "3/9 - Vérification de la version"

$pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml introuvable."
}

$pubspecContent = Get-Content $pubspecPath -Raw

$appVersionMatch = [regex]::Match(
    $pubspecContent,
    '(?m)^version:\s*(.+)$'
)

$msixVersionMatch = [regex]::Match(
    $pubspecContent,
    '(?m)^\s*msix_version:\s*(.+)$'
)

if (-not $appVersionMatch.Success) {
    throw "Version Flutter introuvable dans pubspec.yaml."
}

if (-not $msixVersionMatch.Success) {
    throw "msix_version introuvable dans pubspec.yaml."
}

$appVersion = $appVersionMatch.Groups[1].Value.Trim()
$currentMsixVersion = $msixVersionMatch.Groups[1].Value.Trim()

Write-Host "Version Flutter actuelle : $appVersion"
Write-Host "Version MSIX actuelle    : $currentMsixVersion"

if ($MsixVersion) {
    if ($MsixVersion -notmatch '^\d+\.\d+\.\d+\.\d+$') {
        throw "Le format MsixVersion doit être X.Y.Z.W, par exemple 1.0.2.0"
    }

    Write-Host "Nouvelle version MSIX    : $MsixVersion"

    $pubspecContent = [regex]::Replace(
        $pubspecContent,
        '(?m)^(\s*msix_version:\s*).+$',
        "`$1$MsixVersion"
    )

    Set-Content `
        -Path $pubspecPath `
        -Value $pubspecContent `
        -Encoding UTF8

    $currentMsixVersion = $MsixVersion
}

# ------------------------------------------------------------
# 4. Dépendances Flutter
# ------------------------------------------------------------

Write-Step "4/9 - Dépendances Flutter"

flutter pub get
Assert-LastExitCode "flutter pub get"

$msixDependency = flutter pub deps | Select-String "msix"

if (-not $msixDependency) {
    throw "Le package msix n'est pas présent dans les dépendances."
}

Write-Host "[OK] Package MSIX détecté."

# ------------------------------------------------------------
# 5. Analyse statique
# ------------------------------------------------------------

Write-Step "5/9 - Analyse statique"

flutter analyze
Assert-LastExitCode "flutter analyze"

Write-Host "[OK] flutter analyze réussi."

# ------------------------------------------------------------
# 6. Tests
# ------------------------------------------------------------

Write-Step "6/9 - Tests"

if ($SkipTests) {
    Write-Warning "Tests ignorés à la demande."
}
else {
    flutter test
    Assert-LastExitCode "flutter test"

    Write-Host "[OK] Tests Flutter réussis."
}

# ------------------------------------------------------------
# 7. Nettoyage et build Windows
# ------------------------------------------------------------

Write-Step "7/9 - Build Windows Release"

flutter clean
Assert-LastExitCode "flutter clean"

flutter pub get
Assert-LastExitCode "flutter pub get après clean"

flutter build windows --release
Assert-LastExitCode "flutter build windows --release"

$releaseDir = Join-Path `
    $ProjectRoot `
    "build\windows\x64\runner\Release"

$exePath = Join-Path $releaseDir "focusday.exe"

if (-not (Test-Path $exePath)) {
    throw "focusday.exe introuvable après le build."
}

Write-Host ""
Write-Host "[OK] EXE généré :"
Write-Host $exePath

# ------------------------------------------------------------
# 8. Génération MSIX
# ------------------------------------------------------------

Write-Step "8/9 - Génération MSIX"

dart run msix:create
Assert-LastExitCode "dart run msix:create"

$msixPath = Join-Path $releaseDir "focusday.msix"

if (-not (Test-Path $msixPath)) {
    throw "focusday.msix introuvable après la génération."
}

Write-Host ""
Write-Host "[OK] MSIX généré :"
Write-Host $msixPath

# ------------------------------------------------------------
# 9. Validation du package
# ------------------------------------------------------------

Write-Step "9/9 - Validation du package"

$msixFile = Get-Item $msixPath

Write-Host "Nom          : $($msixFile.Name)"
Write-Host "Taille       : $($msixFile.Length) octets"
Write-Host "Dernière MAJ : $($msixFile.LastWriteTime)"

Write-Host ""
Write-Host "Signature :"

$signature = Get-AuthenticodeSignature $msixPath

$signature |
    Select-Object Status, StatusMessage, SignerCertificate |
    Format-List

Write-Host ""
Write-Host "SHA256 :"

$hash = Get-FileHash `
    -Path $msixPath `
    -Algorithm SHA256

$hash |
    Select-Object Algorithm, Hash, Path |
    Format-List

# ------------------------------------------------------------
# Résumé final
# ------------------------------------------------------------

Write-Step "RELEASE FOCUSDAY TERMINÉE"

Write-Host "Version Flutter : $appVersion"
Write-Host "Version MSIX    : $currentMsixVersion"
Write-Host "Branche Git     : $branch"
Write-Host "Commit          : $localCommit"
Write-Host ""
Write-Host "Package :"
Write-Host $msixPath
Write-Host ""
Write-Host "SHA256 :"
Write-Host $hash.Hash
Write-Host ""
Write-Host "Release Windows générée avec succès."