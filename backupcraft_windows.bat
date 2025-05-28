# ==========================
#  BackupCraft - PowerShell
# ==========================

# 🎮 Apresentação
Write-Host ""
Write-Host "╔════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    🎮  Bem-vindo ao BackupCraft!    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "Este script irá criar um backup do seu mundo do Minecraft Java." -ForegroundColor Gray
Write-Host ""

# Caminhos principais
$savePath = "$env:APPDATA\.minecraft\saves"
$backupPath = "$env:USERPROFILE\Documents\BackupCraft"
$configFile = "$env:LOCALAPPDATA\BackupMinecraftName.txt"

# Função para obter nome do mundo
function Obter-NomeDoMundo {
    if (Test-Path $configFile) {
        $worldName = Get-Content $configFile
        $resposta = Read-Host "Fazer backup do mundo '$worldName'? (s/n)"
        if ($resposta -eq 'n' -or $resposta -eq 'N') {
            $worldName = Read-Host "Digite o nome do mundo"
            $worldName | Set-Content $configFile
        }
    } else {
        $worldName = Read-Host "Digite o nome do mundo"
        $worldName | Set-Content $configFile
    }
    return $worldName
}

# Função de backup
function Fazer-Backup {
    $worldName = Obter-NomeDoMundo
    $worldFolder = Join-Path $savePath $worldName

    if (!(Test-Path $worldFolder)) {
        Write-Host "❌ Mundo '$worldName' não encontrado em $savePath" -ForegroundColor Red
        return
    }

    # Cria a pasta de backup, se não existir
    if (!(Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath | Out-Null
    }

    # Nome do backup com data
    $data = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupFile = "$backupPath\$worldName-backup-$data.zip"

    try {
        # Faz o backup compactando a pasta
        Add-Type -Assembly "System.IO.Compression.FileSystem"
        [System.IO.Compression.ZipFile]::CreateFromDirectory($worldFolder, $backupFile)

        Write-Host "`n✅ Backup criado com sucesso!" -ForegroundColor Green
        Write-Host "Arquivo salvo em:" -ForegroundColor Gray
        Write-Host $backupFile -ForegroundColor Cyan
    }
    catch {
        Write-Host "`n❌ Ocorreu um erro ao criar o backup:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}

# Executa
Fazer-Backup
