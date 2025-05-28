#!/bin/bash

# Caminhos
SAVE_DIR="$HOME/.minecraft/saves"
BACKUP_DIR="$HOME/Documents/Backup Save Minecraft"
CONFIG_FILE="$HOME/.backupcraft_config"

# Função para carregar configurações
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "MULTIPLE_BACKUPS=true" > "$CONFIG_FILE"
    echo "REPLACE_ON_RESTORE=false" >> "$CONFIG_FILE"
    echo "IGNORE_BACKUP_WORLD=true" >> "$CONFIG_FILE"
  fi
  source "$CONFIG_FILE"
}

# Função para salvar configurações
save_config() {
  echo "MULTIPLE_BACKUPS=$MULTIPLE_BACKUPS" > "$CONFIG_FILE"
  echo "REPLACE_ON_RESTORE=$REPLACE_ON_RESTORE" >> "$CONFIG_FILE"
  echo "IGNORE_BACKUP_WORLD=$IGNORE_BACKUP_WORLD" >> "$CONFIG_FILE"
}

# Verifica se a pasta parece ser um mundo válido
is_valid_world() {
  [[ -d "$1" && -f "$1/level.dat" ]]
}

# Lista mundos válidos, ignorando backups se configurado
list_worlds() {
  for d in "$SAVE_DIR"/*; do
    if is_valid_world "$d"; then
      if [[ "$IGNORE_BACKUP_WORLD" == "true" && "$(basename "$d")" == *"(BackupCraft)" ]]; then
        continue
      fi
      echo "$(basename "$d")"
    fi
  done
}

# Lista backups disponíveis
list_backups() {
  for d in "$BACKUP_DIR"/*; do
    # Assumindo backup é pasta que contém pelo menos 1 zip
    if [[ -d "$d" && -n "$(find "$d" -maxdepth 1 -name '*.zip' -print -quit)" ]]; then
      echo "$(basename "$d")"
    fi
  done
}

# Menu de configurações
config_menu() {
  clear
  echo "===== Configurações ====="
  echo "[1] Criar várias versões do backup: $MULTIPLE_BACKUPS"
  echo "[2] Substituir mundo ao restaurar: $REPLACE_ON_RESTORE"
  echo "[3] Ignorar backups restaurados de mundos (com sufixo '(BackupCraft)'): $IGNORE_BACKUP_WORLD"
  echo "[4] Voltar"
  read -p "Escolha: " opt
  case $opt in
    1) MULTIPLE_BACKUPS=$( [[ "$MULTIPLE_BACKUPS" == "true" ]] && echo "false" || echo "true" ); save_config; config_menu;;
    2) REPLACE_ON_RESTORE=$( [[ "$REPLACE_ON_RESTORE" == "true" ]] && echo "false" || echo "true" ); save_config; config_menu;;
    3) IGNORE_BACKUP_WORLD=$( [[ "$IGNORE_BACKUP_WORLD" == "true" ]] && echo "false" || echo "true" ); save_config; config_menu;;
    *) return;;
  esac
}

# Faz backup de um mundo
backup_world() {
  mapfile -t worlds < <(list_worlds)

  echo "===== Mundos Disponíveis ====="
  select world in "${worlds[@]}"; do
    [[ -n "$world" ]] && break
  done
  local src="$SAVE_DIR/$world"
  local dest_dir="$BACKUP_DIR/$world"
  mkdir -p "$dest_dir"

  if [[ "$MULTIPLE_BACKUPS" == "true" ]]; then
    local timestamp=$(date +"%d-%m-%Y_%H-%M-%S")
    (cd "$SAVE_DIR" && zip -r "$dest_dir/${world}_$timestamp.zip" "$world" > /dev/null)
  else
    rm -f "$dest_dir"/*.zip
    (cd "$SAVE_DIR" && zip -r "$dest_dir/${world}.zip" "$world" > /dev/null)
  fi

  echo "Backup criado para '$world'."
  read -p "Pressione Enter para continuar..."
}

# Restaura um backup
restore_backup() {
  IFS=$'\n' read -r -d '' -a backups < <(list_backups && printf '\0')
  echo "===== Backups Disponíveis ====="
  select backup in "${backups[@]}"; do
    [[ -n "$backup" ]] && break
  done

  local backup_folder="$BACKUP_DIR/$backup"
  local zipfile=$(find "$backup_folder" -name '*.zip' | sort | tail -n1)

  # Nome original do mundo no backup (extraído do nome do zip)
  local base_name=$(basename "$zipfile" .zip)
  # Remove possível timestamp, deixando só nome do mundo (considerando que o nome do zip é "nome_timestamp.zip" ou "nome.zip")
  local world_name="${base_name%%_*}"  # pega até o primeiro _

  # Caminho do mundo original e o destino
  local original_world_path="$SAVE_DIR/$world_name"
  local new_world_name="${world_name} (BackupCraft)"
  local new_world_path="$SAVE_DIR/$new_world_name"

  if [[ "$REPLACE_ON_RESTORE" == "true" ]]; then
    # Apaga o mundo original (pra evitar mistura)
    rm -rf "$original_world_path"
    # Descompacta direto na pasta de saves, vai criar "$world_name"
    unzip -oq "$zipfile" -d "$SAVE_DIR"
    echo "Backup de '$world_name' restaurado substituindo o mundo original."
  else
    # Se existir a pasta renomeada, apaga antes pra evitar confusão
    rm -rf "$new_world_path"

    # Cria uma pasta temporária pra descompactar
    local tmp_dir=$(mktemp -d)
    unzip -q "$zipfile" -d "$tmp_dir"

    # A pasta dentro do zip tem o nome original do mundo
    # Move ela para a pasta de saves, renomeando
    mv "$tmp_dir/$world_name" "$new_world_path"

    # Remove a pasta temporária
    rmdir "$tmp_dir"

    echo "Backup de '$world_name' restaurado como '$new_world_name'."
  fi

  read -p "Pressione Enter para continuar..."
}


# Menu principal
main_menu() {
  load_config
  while true; do
    clear
    echo "===== Bem-vindo ao BackupCraft! ====="
    echo "[1] Fazer backup"
    echo "[2] Carregar um backup"
    echo "[3] Configurações"
    echo "[4] Sair"
    read -p "Escolha: " opt
    case $opt in
      1) backup_world;;
      2) restore_backup;;
      3) config_menu;;
      4) exit;;
      *) echo "Opção inválida."; sleep 1;;
    esac
  done
}

main_menu
