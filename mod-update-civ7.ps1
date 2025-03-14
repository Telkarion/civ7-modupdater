param (
    [switch] $Local,
    [string]$WorkingDirectory = (Get-Location).Path
)

$destinationDirectory = "$env:LOCALAPPDATA\Firaxis Games\Sid Meier's Civilization VII\Mods"
#$destinationDirectory = "$env:HOMEDRIVE$env:HOMEPATH\test"
$logFile = Join-Path -Path $destinationDirectory -ChildPath "mod-update-civ7.log"
$urlFilename = "modsurls"
$urlsFileUrl = "https://raw.githubusercontent.com/Telkarion/civ7-modupdater/refs/heads/main/$urlFilename"

Set-Location -Path $WorkingDirectory

# Fonction pour écrire des logs avec un timestamp
function log
{
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}



# Vérifier si le répertoire de destination existe
if (-not (Test-Path $destinationDirectory)) {
    Write-Host "Le répertoire de destination n'existe pas : $destinationDirectory" -ForegroundColor DarkYellow
    exit
}

if (-not $Local)
{
    Write-Host "=== ATTENTION ====" -ForegroundColor yellow -BackgroundColor red
    Write-Host "Ce script va supprimer tout le contenu du répertoire de destination (mais le remplir avec une liste de mods civ7 juteuse :3 ) " -ForegroundColor yellow
    Write-Host " Répertoire ciblé : $destinationDirectory" -ForegroundColor green
    $confirmation = Read-Host "Voulez-vous continuer ? (Tapez 'Oui' pour confirmer)"

    if ($confirmation -ne "Oui")
    {
        log "Opération annulée par l'utilisateur."
        exit
    }
}
else {
    log "Mode local actif"
}


if (-not (Get-Module -ListAvailable -Name 7Zip4PowerShell)) {

    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        # Relancer le script avec des privilèges élevés
        Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }

    #   Install 7zip module
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name 'PSGallery' -SourceLocation "https://www.powershellgallery.com/api/v2" -InstallationPolicy Trusted
    Install-Module -Name 7Zip4PowerShell -Force

    # Vérifier l'installation du module
    if (-not (Get-Module -ListAvailable -Name 7Zip4PowerShell)) {
        log "Le module 7Zip4PowerShell n'est pas installé correctement."
        exit
    }

}

# Purger le répertoire de destination
if (Test-Path $destinationDirectory)
{
    Remove-Item $destinationDirectory\* -Recurse -Force
}
else
{
    New-Item -ItemType Directory -Path $destinationDirectory
}


# Télécharger et lire les URLs à partir du fichier texte distant

$urlsFilePath = Join-Path -Path $destinationDirectory -ChildPath "urls.txt"

if ($Local)
{
    Copy-Item -Path ".\$urlFilename" -Destination $urlsFilePath
}
else
{
    try
    {
        Invoke-WebRequest -Uri $urlsFileUrl -OutFile $urlsFilePath
        log "Liste des URLs récupérée avec succès."
    }
    catch
    {
        log "Erreur lors de la récupération de la liste des URLs. Utilisez -local si vous voulez utiliser une liste locale."
        Read-Host "Appuyez sur Entrée pour continuer"
        exit
    }
}

# Télécharger et décompresser chaque fichier ZIP
$zipUrls = Get-Content -Path $urlsFilePath
foreach ($url in $zipUrls)
{
    $downloadUrl = "$url/download"
    # Télécharger le fichier ZIP
    $response = Invoke-WebRequest -Uri $downloadUrl -Method Head
    $zipFileName = $response.Headers["Content-Disposition"] -split ";" | ForEach-Object { $_.Trim() } | Where-Object { $_ -like "filename=*" } | ForEach-Object { $_ -replace "filename=", "" } | ForEach-Object { $_.Trim('"') }

    if (-not $zipFileName)
    {
        log "Impossible de déterminer le nom du fichier pour l'URL : $downloadUrl"
        continue
    }

    # Ajouter l'extension .zip si elle n'est pas déjà présente
    if (-not ( $zipFileName.EndsWith(".zip") -or $zipFileName.EndsWith(".7z") -or $zipFileName.EndsWith(".rar")))
    {
        $zipFileName = "$zipFileName.zip"
    }

    log "Récupération du mod $zipFileName"

    $zipFilePath = Join-Path -Path $destinationDirectory -ChildPath $zipFileName
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFilePath

    # Décompresser le fichier ZIP dans le répertoire de destination
    switch ($zipFileName) {
        { $_.EndsWith(".7z") } {
            Expand-7Zip -ArchiveFileName $zipFilePath -TargetPath $destinationDirectory
        }
        { $_.EndsWith(".zip") } {
            Expand-Archive -Path $zipFilePath -DestinationPath $destinationDirectory
        }
        { $_.EndsWith(".rar") } {
            Write-Host "RAR not supported yet"
        }
        Default {
            log "Aucun décompresseur disponible pour le fichier $_"
        }
    }

    # Supprimer le fichier ZIP après décompression
    Remove-Item -Path $zipFilePath
}


log "Civilization 7 paré et moddé :)"
Read-Host "Appuyez sur Entrée pour continuer"