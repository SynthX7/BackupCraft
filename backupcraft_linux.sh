#!/bin/bash

# Caminhos
SAVE_DIR="$HOME/.minecraft/saves"
BACKUP_DIR="$(xdg-user-dir DOCUMENTS)/Backup Save Minecraft"
HIDDEN_BACKUP_DIR="$HOME/.local/share/.backupcraft_hidden"
CONFIG_FILE="$HOME/.backupcraft_config"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color (reset)

# Caminho do arquivo de log
LOG_FILE="$HOME/.backupcraft_log"

# Função de log
log_action() {
  local message="$1"
  echo "[$(date +"%d/%m/%Y %H:%M:%S")] $message" >> "$LOG_FILE"
}

# Função para carregar configurações
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "MULTIPLE_BACKUPS=true" > "$CONFIG_FILE"
    echo "REPLACE_ON_RESTORE=false" >> "$CONFIG_FILE"
    echo "IGNORE_BACKUP_WORLD=true" >> "$CONFIG_FILE"
    echo "ENABLE_HIDDEN_BACKUP=true" >> "$CONFIG_FILE"
  fi
  source "$CONFIG_FILE"
}

# Função para salvar configurações
save_config() {
  {
    echo "MULTIPLE_BACKUPS=$MULTIPLE_BACKUPS"
    echo "REPLACE_ON_RESTORE=$REPLACE_ON_RESTORE"
    echo "IGNORE_BACKUP_WORLD=$IGNORE_BACKUP_WORLD"
    echo "ENABLE_HIDDEN_BACKUP=$ENABLE_HIDDEN_BACKUP"
  } > "$CONFIG_FILE"
}

# Verifica se a pasta parece ser um mundo válido
is_valid_world() {
  [[ -d "$1" && -f "$1/level.dat" ]]
}

# Lista mundos válidos
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

# Lista backups
list_backups() {
  for d in "$BACKUP_DIR"/*; do
    if [[ -d "$d" && -n "$(find "$d" -maxdepth 1 -name '*.zip' -print -quit)" ]]; then
      echo "$(basename "$d")"
    fi
  done
}

# Inicia animação de loading em segundo plano e guarda o PID
start_loading() {
  local chars='|/-\'
  while :; do
    for ((i=0; i<${#chars}; i++)); do
      echo -ne "\r${chars:$i:1}"  # barra giratória
      sleep 0.1
    done
  done
}

# Inicia a animação e salva o PID em uma variável global
animate_loading() {
  start_loading &
  LOADING_PID=$!
  disown
}

# Para a animação
stop_loading() {
  kill "$LOADING_PID" 2>/dev/null
  wait "$LOADING_PID" 2>/dev/null
  echo -ne "\r"  # limpa a linha
}



# Configurações
config_menu() {
  while true; do
    clear
    echo "===== Configurações ====="
    echo "[1] Backups versionados: $( [[ "$MULTIPLE_BACKUPS" == "true" ]] && echo -e "${GREEN}Ativado${NC}" || echo -e "${RED}Desativado${NC}" )"
    echo "[2] Substituir mundo ao restaurar: $( [[ "$REPLACE_ON_RESTORE" == "true" ]] && echo -e "${GREEN}Ativado${NC}" || echo -e "${RED}Desativado${NC}" )"
    echo "[3] Ignorar mundos restaurados (com o sufixo 'BackupCraft'): $( [[ "$IGNORE_BACKUP_WORLD" == "true" ]] && echo -e "${GREEN}Ativado${NC}" || echo -e "${RED}Desativado${NC}" )"
    echo "[4] Backup oculto extra (medida de segurança): $( [[ "$ENABLE_HIDDEN_BACKUP" == "true" ]] && echo -e "${GREEN}Ativado${NC}" || echo -e "${RED}Desativado${NC}" )"
    echo "[5] Voltar"
    read -p "Escolha: " opt
    case $opt in
      1) MULTIPLE_BACKUPS=$([[ "$MULTIPLE_BACKUPS" == "true" ]] && echo "false" || echo "true");;
      2) REPLACE_ON_RESTORE=$([[ "$REPLACE_ON_RESTORE" == "true" ]] && echo "false" || echo "true");;
      3) IGNORE_BACKUP_WORLD=$([[ "$IGNORE_BACKUP_WORLD" == "true" ]] && echo "false" || echo "true");;
      4) ENABLE_HIDDEN_BACKUP=$([[ "$ENABLE_HIDDEN_BACKUP" == "true" ]] && echo "false" || echo "true");;
      5) save_config; return;;
      *) echo "Opção inválida.";;
    esac
    save_config
  done
}

# Backup
backup_world() {
  mapfile -t worlds < <(list_worlds)
  echo "===== Mundos Disponíveis ====="
  select world in "${worlds[@]}" "Voltar"; do
    [[ "$REPLY" == "${#worlds[@]}+1" || "$world" == "Voltar" ]] && return
    [[ -n "$world" ]] && break
  done
  [[ -z "$world" ]] && return

  local src="$SAVE_DIR/$world"
  local dest_dir="$BACKUP_DIR/$world"
  local hidden_dest="$HIDDEN_BACKUP_DIR/$world"
  local timestamp=$(date +"%d-%m-%Y_%H-%M-%S")
  local zipname="${world}_$timestamp.zip"
  local zip_single="${world}.zip"

  echo -e "${GREEN}[✔] Mundo selecionado:${NC} $world"
  echo -n "[...] Criando diretórios de destino... "
  mkdir -p "$dest_dir" && mkdir -p "$hidden_dest"
  echo -e "${GREEN}OK${NC}"

  echo -n "[...] Compactando mundo..."
  animate_loading & pid=$!
  if [[ "$MULTIPLE_BACKUPS" == "true" ]]; then
    (cd "$SAVE_DIR" && zip -rq "$dest_dir/$zipname" "$world")
    [[ "$ENABLE_HIDDEN_BACKUP" == "true" ]] && (cd "$SAVE_DIR" && zip -rq "$hidden_dest/$zipname" "$world")
  else
    rm -f "$dest_dir"/*.zip "$hidden_dest"/*.zip
    (cd "$SAVE_DIR" && zip -rq "$dest_dir/$zip_single" "$world")
    [[ "$ENABLE_HIDDEN_BACKUP" == "true" ]] && (cd "$SAVE_DIR" && zip -rq "$hidden_dest/$zip_single" "$world")
  fi
  kill $pid >/dev/null 2>&1 && wait $pid 2>/dev/null
  echo -e "\r[✔] Backup finalizado para '$world'."

  read -p "Pressione Enter para continuar..."
}


# Restaurar
restore_backup() {
  IFS=$'\n' read -r -d '' -a backups < <(list_backups && printf '\0')
  echo "===== Backups Disponíveis ====="
  select backup in "${backups[@]}" "Voltar"; do
    [[ "$backup" == "Voltar" || "$REPLY" == "${#backups[@]}+1" ]] && return
    [[ -n "$backup" ]] && break
  done
  [[ -z "$backup" ]] && return

  local backup_folder="$BACKUP_DIR/$backup"
  local zipfile=$(find "$backup_folder" -name '*.zip' | sort | tail -n1)

  if [[ ! -f "$zipfile" ]]; then
    echo "Backup inválido ou corrompido."
    read -p "Pressione Enter para continuar..."
    return
  fi

  local base_name=$(basename "$zipfile" .zip)
  local world_name="${base_name%%_*}"
  local original_path="$SAVE_DIR/$world_name"
  local new_world_path="$SAVE_DIR/${world_name} (BackupCraft)"

  if [[ "$REPLACE_ON_RESTORE" == "true" ]]; then
    read -p "Deseja substituir o mundo original '$world_name'? (s/N): " confirm
    [[ "$confirm" != "s" ]] && return
    rm -rf "$original_path"
    unzip -oq "$zipfile" -d "$SAVE_DIR"
    log_action "Backup restaurado: '$zipfile' → '$original_path' (Substituído)"

  else
    rm -rf "$new_world_path"
    local tmp=$(mktemp -d)
    unzip -q "$zipfile" -d "$tmp"
    mv "$tmp/$world_name" "$new_world_path" 2>/dev/null || echo "Falha ao mover arquivos."
    log_action "Backup restaurado: '$zipfile' → '$new_world_path' (Novo mundo)"
  fi
  read -p "Pressione Enter para continuar..."
}

# Menu principal
main_menu() {
  load_config
  while true; do
    clear
    echo "===== Bem-vindo ao BackupCraft! ====="
    echo "[1] Fazer Backup"
    echo "[2] Restaurar Backup"
    echo "[3] Configurações"
    echo "[4] Sair"
    read -p "Escolha uma opção: " op
    case $op in
      1) backup_world ;;
      2) restore_backup ;;
      3) config_menu ;;
      4) clear; exit ;;
      *) echo "Opção inválida."; sleep 1 ;;
    esac
  done
}

main_menu
