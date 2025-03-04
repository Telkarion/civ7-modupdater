$destinationDirectory = "$env:LOCALAPPDATA\Firaxis Games\Sid Meier's Civilization VII\Mods"
#$destinationDirectory = "$env:HOMEDRIVE$env:HOMEPATH\test"
$logFile = Join-Path -Path $destinationDirectory -ChildPath "mod-update-civ7.log"

# Fonction pour écrire des logs avec un timestamp
function log {
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


Write-Host "=== ATTENTION ====" -ForegroundColor yellow -BackgroundColor red 
Write-Host "Ce script va supprimer tout le contenu du répertoire de destination (mais le remplir avec une liste de mods civ7 juteuse :3 ) " -ForegroundColor yellow 
Write-Host " Répertoire ciblé : $destinationDirectory" -ForegroundColor green 
$confirmation = Read-Host "Voulez-vous continuer ? (Tapez 'Oui' pour confirmer)"

if ($confirmation -ne "Oui") {
    log "Opération annulée par l'utilisateur."
    exit
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


# Liste des URLs des fichiers ZIP à télécharger
$zipUrls = @(
    "https://forums.civfanatics.com/resources/tcs-improved-plot-tooltip.31859",
    "https://forums.civfanatics.com/resources/sukritacts-simple-ui-adjustments.31860",
    "https://forums.civfanatics.com/resources/ynamp-larger-map-tsl-continents-beta.31855",
    "https://forums.civfanatics.com/resources/trade-lens.31886",
    "https://forums.civfanatics.com/resources/artificially-intelligent-ai-mod.31881",
    "https://forums.civfanatics.com/resources/detailed-tech-civic-progress.31924"
)

# Purger le répertoire de destination
if (Test-Path $destinationDirectory) {
    Remove-Item $destinationDirectory\* -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $destinationDirectory
}

# Télécharger et décompresser chaque fichier ZIP
foreach ($url in $zipUrls) {
    $downloadUrl = "$url/download"
    # Télécharger le fichier ZIP
    $response = Invoke-WebRequest -Uri $downloadUrl -Method Head    
    $zipFileName = $response.Headers["Content-Disposition"] -split ";" | ForEach-Object { $_.Trim() } | Where-Object { $_ -like "filename=*" } | ForEach-Object { $_ -replace "filename=", "" } | ForEach-Object { $_.Trim('"') }

    if (-not $zipFileName) {
        log "Impossible de déterminer le nom du fichier pour l'URL : $downloadUrl"
        continue
    }

     # Ajouter l'extension .zip si elle n'est pas déjà présente
    if  ( -not ( $zipFileName.EndsWith(".zip") -or $zipFileName.EndsWith(".7z"))) {
        $zipFileName = "$zipFileName.zip"
    }

    log "Récupération du mod $zipFileName"

    $zipFilePath = Join-Path -Path $destinationDirectory -ChildPath $zipFileName
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFilePath

    # Décompresser le fichier ZIP dans le répertoire de destination
    if ($zipFileName.EndsWith(".zip")) {
        Expand-Archive -Path $zipFilePath -DestinationPath $destinationDirectory
    } elseif ($zipFileName.EndsWith(".7z")) {
        Expand-7Zip -ArchiveFileName $zipFilePath -TargetPath $destinationDirectory
    }

    # Supprimer le fichier ZIP après décompression
    Remove-Item -Path $zipFilePath       
}


log "Civilization 7 paré et moddé :)"