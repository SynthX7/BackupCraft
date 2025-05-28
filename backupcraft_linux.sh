#!/bin/bash

# ================
#  🎮 BackupCraft
# ================

# 🎉 Apresentação
echo
echo -e "\e[96m╔════════════════════════════════════╗"
echo -e "║   🎮  Bem-vindo ao BackupCraft!    ║"
echo -e "╚════════════════════════════════════╝\e[0m"
echo -e "\e[90mEste script criará um backup do seu mundo do Minecraft Java.\e[0m"
echo

# Caminhos
SAVE_PATH="$HOME/.minecraft/saves"
BACKUP_PATH="$HOME/Documents/BackupCraft"
CONFIG_FILE="$HOME/.config/backupcraft_mundo.txt"

# Cria pasta de config se não existir
mkdir -p "$(dirname "$CONFIG_FILE")"

# Obter nome do mundo
if [ -f "$CONFIG_FILE" ]; then
    WORLD_NAME=$(cat "$CONFIG_FILE")
    read -p "Fazer backup do mundo '$WORLD_NAME'? (s/n): " RESP
    if [[ "$RESP" =~ ^[Nn]$ ]]; then
        read -p "Digite o nome do mundo: " WORLD_NAME
        echo "$WORLD_NAME" > "$CONFIG_FILE"
    fi
else
    read -p "Digite o nome do mundo: " WORLD_NAME
    echo "$WORLD_NAME" > "$CONFIG_FILE"
fi

WORLD_FOLDER="$SAVE_PATH/$WORLD_NAME"

# Verifica se a pasta do mundo existe
if [ ! -d "$WORLD_FOLDER" ]; then
    echo -e "\e[91m❌ Mundo '$WORLD_NAME' não encontrado em $SAVE_PATH\e[0m"
    exit 1
fi

# Cria pasta de backup se necessário
mkdir -p "$BACKUP_PATH"

# Data e nome do backup
DATA=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_FILE="$BACKUP_PATH/${WORLD_NAME}-backup-${DATA}.zip"

# Compactar o backup
if zip -r "$BACKUP_FILE" "$WORLD_FOLDER" > /dev/null; then
    echo -e "\n\e[92m✅ Backup criado com sucesso!\e[0m"
    echo -e "Arquivo salvo em:\n\e[96m$BACKUP_FILE\e[0m"
else
    echo -e "\n\e[91m❌ Ocorreu um erro ao criar o backup!\e[0m"
fi
