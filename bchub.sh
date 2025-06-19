#!/bin/bash

# Caminhos
SAVE_DIR="$HOME/.minecraft/saves"
BACKUP_DIR="$(xdg-user-dir DOCUMENTS)/Backup Save Minecraft"
HIDDEN_BACKUP_DIR="$HOME/.local/share/.backupcraft_hidden"
CONFIG_FILE="$HOME/.backupcraft_config"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color (reset)

# Arquivo de log
LOG_FILE="$HOME/.backupcraft_log"

# Verifica se o 7zip está instalado
if ! command -v 7z &> /dev/null; then
    echo -e "${RED}Erro: 7zip não está instalado. Instale-o com 'sudo apt install p7zip-full' ou equivalente para sua distribuição.${NC}"
    exit 1
fi

# Função de log
log_action() {
  local message="$1"
  echo "[$(date +"%d/%m/%Y %H:%M:%S")] $message" >> "$LOG_FILE"
}

# Carregar configurações
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << EOF
MULTIPLE_BACKUPS=true
REPLACE_ON_RESTORE=false
IGNORE_BACKUP_WORLD=true
ENABLE_HIDDEN_BACKUP=true
ENABLE_ENCRYPTION=false
ENCRYPTION_PASSWORD=""
AUTO_BACKUP=false
AUTO_BACKUP_INTERVAL=3600
EOF
  fi
  source "$CONFIG_FILE"
}

# Verifica diretórios
if [[ ! -d "$SAVE_DIR" ]]; then
  echo -e "${RED}Erro: Diretório de saves do Minecraft não encontrado em $SAVE_DIR${NC}"
  exit 1
fi
mkdir -p "$BACKUP_DIR" "$HIDDEN_BACKUP_DIR"

# Salvar configurações
save_config() {
  cat > "$CONFIG_FILE" << EOF
MULTIPLE_BACKUPS=$MULTIPLE_BACKUPS
REPLACE_ON_RESTORE=$REPLACE_ON_RESTORE
IGNORE_BACKUP_WORLD=$IGNORE_BACKUP_WORLD
ENABLE_HIDDEN_BACKUP=$ENABLE_HIDDEN_BACKUP
ENABLE_ENCRYPTION=$ENABLE_ENCRYPTION
ENCRYPTION_PASSWORD="$ENCRYPTION_PASSWORD"
AUTO_BACKUP=$AUTO_BACKUP
AUTO_BACKUP_INTERVAL=$AUTO_BACKUP_INTERVAL
EOF
}

# Barra de progresso estilizada
fancy_progress_bar() {
  local progress=$1
  local total=$2
  local width=40
  local filled=$(( progress * width / total ))
  local empty=$(( width - filled ))
  local percentage=$(( progress * 100 / total ))

  local bar="\e[32m["
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+=" "; done
  bar+="\e[0m] ${YELLOW}${percentage}%%\e[0m"

  local remaining=$(( total - progress ))
  bar+=" (${remaining}s restantes)"

  echo -ne "\r$bar"
}

# Simula progresso proporcional ao tamanho
simulate_progress_by_size() {
  local size_bytes=$1
  local max_time=30
  local time_sec=$(( size_bytes / 1000000 ))
  (( time_sec > max_time )) && time_sec=$max_time
  (( time_sec < 5 )) && time_sec=5

  local steps=$time_sec
  for ((i=0; i<=steps; i++)); do
    fancy_progress_bar $i $steps
    sleep 1
  done
  echo
}

# Verifica se pasta é mundo válido
is_valid_world() {
  [[ -d "$1" && -f "$1/level.dat" ]]
}

# Lista mundos válidos
list_worlds() {
  for d in "$SAVE_DIR"/*; do
    if is_valid_world "$d"; then
      if [[ "$IGNORE_BACKUP_WORLD" == "true" && "$(basename "$d")" == *(BackupCraft) ]]; then
        continue
      fi
      echo "$(basename "$d")"
    fi
  done
}

# Lista backups válidos
list_backups() {
  for d in "$BACKUP_DIR"/*; do
    if [[ -d "$d" && -n "$(find "$d" -maxdepth 1 -name '*.7z' -print -quit)" ]]; then
      echo "$(basename "$d")"
    fi
  done
}

# Compressão incremental
incremental_backup() {
  local src_dir="$1"
  local dest_dir="$2"
  local tmp_backup_dir="$HOME/.backupcraft_tmp"

  mkdir -p "$tmp_backup_dir"
  rm -rf "$tmp_backup_dir"/*

  rsync -a --delete "$src_dir/" "$tmp_backup_dir/"

  local zip_file="$3"
  if [[ "$ENABLE_ENCRYPTION" == "true" && -n "$ENCRYPTION_PASSWORD" ]]; then
    (cd "$tmp_backup_dir" && 7z a -t7z -p"$ENCRYPTION_PASSWORD" -mhe=on "$zip_file" .) >/dev/null
  else
    (cd "$tmp_backup_dir" && 7z a -t7z "$zip_file" .) >/dev/null
  fi
  rm -rf "$tmp_backup_dir"
}

# Backup do mundo
backup_world() {
  mapfile -t worlds < <(list_worlds)
  if [ ${#worlds[@]} -eq 0 ]; then
    echo -e "${RED}Nenhum mundo válido encontrado para backup.${NC}"
    read -p "Pressione Enter para continuar..."
    return
  fi

  echo "===== Mundos Disponíveis ====="
  select world in "${worlds[@]}" "Voltar"; do
    [[ "$REPLY" == $((${#worlds[@]}+1)) || "$world" == "Voltar" ]] && return
    if [[ -n "$world" ]]; then
      local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
      local backup_name
      if [[ "$MULTIPLE_BACKUPS" == "true" ]]; then
        backup_name="${world} (${timestamp})"
      else
        backup_name="${world}"
      fi

      mkdir -p "$BACKUP_DIR/$backup_name"

      echo "Preparando backup do mundo '$world'..."

      local world_path="$SAVE_DIR/$world"
      local size_kb=$(du -s "$world_path" | cut -f1)
      local size_mb=$((size_kb / 1024))

      if (( size_mb == 0 )); then
        size_mb=1
      fi

      echo "Iniciando compressão..."
      simulate_progress_by_size $((size_kb * 1024))

      if [[ "$ENABLE_ENCRYPTION" == "true" && -n "$ENCRYPTION_PASSWORD" ]]; then
        (cd "$world_path" && 7z a -t7z -p"$ENCRYPTION_PASSWORD" -mhe=on "$BACKUP_DIR/$backup_name/${world}.7z" .) >/dev/null
      else
        (cd "$world_path" && 7z a -t7z "$BACKUP_DIR/$backup_name/${world}.7z" .) >/dev/null
      fi

      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Backup criado com sucesso em: $BACKUP_DIR/$backup_name/${world}.7z${NC}"
        log_action "Backup criado: $backup_name/$world.7z"
      else
        echo -e "${RED}Erro ao criar o backup! Verifique permissões ou espaço em disco.${NC}"
        log_action "Erro ao criar backup: $backup_name/$world.7z (Código: $?)"
        read -p "Pressione Enter para continuar..."
        return
      fi

      if [[ "$ENABLE_HIDDEN_BACKUP" == "true" ]]; then
        echo "Criando backup oculto..."
        mkdir -p "$HIDDEN_BACKUP_DIR"
        cp -r "$world_path" "$HIDDEN_BACKUP_DIR/${world}_hidden"
        log_action "Backup oculto criado: ${world}_hidden"
        simulate_progress_by_size $((size_kb * 1024 / 2))
      fi

      read -p "Backup finalizado. Pressione Enter para continuar..."
      return
    else
      echo "Opção inválida."
    fi
  done
}

# Restaurar backup
restore_backup() {
  mapfile -t backups < <(list_backups)
  if [ ${#backups[@]} -eq 0 ]; then
    echo -e "${RED}Nenhum backup encontrado.${NC}"
    read -p "Pressione Enter para continuar..."
    return
  fi

  echo "===== Backups Disponíveis ====="
  select backup in "${backups[@]}" "Voltar"; do
    [[ "$REPLY" == $((${#backups[@]}+1)) || "$backup" == "Voltar" ]] && return
    if [[ -n "$backup" ]]; then
      echo "Restaurar backup '$backup'..."

      local backup_path="$BACKUP_DIR/$backup"
      local zip_file
      zip_file=$(find "$backup_path" -maxdepth 1 -name '*.7z' | head -n 1)

      if [[ ! -f "$zip_file" ]]; then
        echo -e "${RED}Arquivo de backup não encontrado!${NC}"
        read -p "Pressione Enter para continuar..."
        return
      fi

      local restore_dir_name="$backup"
      if [[ "$backup" == *"(BackupCraft)"* ]]; then
        restore_dir_name="$backup"
        echo -e "${YELLOW}Restaurando backup nomeado '(BackupCraft)', cuidado para não sobrescrever mundos importantes.${NC}"
      fi

      local restore_path="$SAVE_DIR/$restore_dir_name"

      if [[ -d "$restore_path" ]]; then
        if [[ "$REPLACE_ON_RESTORE" == "true" ]]; then
          rm -rf "$restore_path"
          echo "Diretório existente removido para substituição."
        else
          echo -e "${RED}Diretório já existe e substituição está desativada. Operação cancelada.${NC}"
          read -p "Pressione Enter para continuar..."
          return
        fi
      fi

      mkdir -p "$restore_path"

      if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
        read -s -p "Digite a senha do backup: " input_password
        echo
        if ! 7z t -p"$input_password" "$zip_file" >/dev/null 2>&1; then
          echo -e "${RED}Senha incorreta ou arquivo corrompido!${NC}"
          log_action "Erro na restauração: Senha incorreta para $backup"
          read -p "Pressione Enter para continuar..."
          return
        fi
        7z x -p"$input_password" "$zip_file" -o"$restore_path" >/dev/null
      else
        7z x "$zip_file" -o"$restore_path" >/dev/null
      fi

      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Backup restaurado com sucesso em: $restore_path${NC}"
        log_action "Backup restaurado: $backup"
      else
        echo -e "${RED}Falha ao restaurar o backup!${NC}"
        log_action "Erro na restauração: $backup"
      fi

      read -p "Pressione Enter para continuar..."
      return
    else
      echo "Opção inválida."
    fi
  done
}

# Limpar backups antigos
clean_old_backups() {
  local max_backups=10
  mapfile -t backups < <(ls -d "$BACKUP_DIR"/*/ | sort -r)
  if [ ${#backups[@]} -gt $max_backups ]; then
    for ((i=$max_backups; i<${#backups[@]}; i++)); do
      rm -rf "${backups[$i]}"
      log_action "Backup antigo removido: ${backups[$i]}"
    done
    echo "Backups antigos removidos (mantidos os $max_backups mais recentes)."
  else
    echo "Nenhum backup antigo para remover."
  fi
  read -p "Pressione Enter para continuar..."
}

# Backup automático
auto_backup_loop() {
  echo "Backup automático iniciado. Intervalo: $AUTO_BACKUP_INTERVAL segundos."
  while true; do
    world_to_backup=$(list_worlds | head -n1)
    if [[ -n "$world_to_backup" ]]; then
      echo "Executando backup automático do mundo '$world_to_backup'..."
      backup_world_auto "$world_to_backup"
    else
      echo "Nenhum mundo válido encontrado para backup automático."
    fi
    sleep "$AUTO_BACKUP_INTERVAL"
  done
}

backup_world_auto() {
  local world="$1"
  local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  local backup_name
  if [[ "$MULTIPLE_BACKUPS" == "true" ]]; then
    backup_name="${world} (${timestamp})"
  else
    backup_name="${world}"
  fi

  mkdir -p "$BACKUP_DIR/$backup_name"
  local world_path="$SAVE_DIR/$world"
  local zip_file="$BACKUP_DIR/$backup_name/${world}.7z"

  echo "Backup automático: compactando '$world'..."

  if [[ "$ENABLE_ENCRYPTION" == "true" && -n "$ENCRYPTION_PASSWORD" ]]; then
    (cd "$world_path" && 7z a -t7z -p"$ENCRYPTION_PASSWORD" -mhe=on "$zip_file" .) >/dev/null
  else
    (cd "$world_path" && 7z a -t7z "$zip_file" .) >/dev/null
  fi

  if [[ $? -eq 0 ]]; then
    echo "Backup automático concluído: $zip_file"
    log_action "Backup automático criado: $backup_name/$world.7z"
  else
    echo "Erro no backup automático!"
    log_action "Erro no backup automático: $backup_name/$world.7z"
  fi
}

# Menu de configurações
config_menu() {
  while true; do
    clear
    echo "===== Configurações ====="
    echo "[1] Backups versionados: $( [[ \"$MULTIPLE_BACKUPS\" == \"true\" ]] && echo -e \"${GREEN}Ativado${NC}\" || echo -e \"${RED}Desativado${NC}\" )"
    echo "[2] Substituir mundo ao restaurar: $( [[ \"$REPLACE_ON_RESTORE\" == \"true\" ]] && echo -e \"${GREEN}Ativado${NC}\" || echo -e \"${RED}Desativado${NC}\" )"
    echo "[3] Ignorar mundos restaurados (com sufixo 'BackupCraft'): $( [[ \"$IGNORE_BACKUP_WORLD\" == \"true\" ]] && echo -e \"${GREEN}Ativado${NC}\" || echo -e \"${RED}Desativado${NC}\" )"
    echo "[4] Backup oculto extra (medida de segurança): $( [[ \"$ENABLE_HIDDEN_BACKUP\" == \"true\" ]] && echo -e \"${GREEN}Ativado${NC}\" || echo -e \"${RED}Desativado${NC}\" )"
    echo "[5] Criptografia dos backups: $( [[ \"$ENABLE_ENCRYPTION\" == \"true\" ]] && echo -e \"${GREEN}Ativado${NC}\" || echo -e \"${RED}Desativado${NC}\" )"
    echo "[6] Senha para criptografia: $( [[ -n \"$ENCRYPTION_PASSWORD\" ]] && echo -e \"${YELLOW}Definida${NC}\" || echo -e \"${RED}Não definida${NC}\" )"
    echo "[7] Backup automático: $( [[ \"$AUTO_BACKUP\" == \"true\" ]] && echo -e \"${GREEN}Ativado${NC}\" || echo -e \"${RED}Desativado${NC}\" )"
    echo "[8] Intervalo do backup automático (segundos): $AUTO_BACKUP_INTERVAL"
    echo "[9] Voltar"
    read -p "Escolha: " opt
    case $opt in
      1) MULTIPLE_BACKUPS=$([[ "$MULTIPLE_BACKUPS" == "true" ]] && echo "false" || echo "true");;
      five) ENABLE_ENCRYPTION=$([[ "$ENABLE_ENCRYPTION" == "true" ]] && echo "false" || echo "true");;
      6) read -s -p "Digite a nova senha: " ENCRYPTION_PASSWORD; echo;;
      7) AUTO_BACKUP=$([[ "$AUTO_BACKUP" == "true" ]] && echo "false" || echo "true");;
      8) read -p "Novo intervalo (segundos): " AUTO_BACKUP_INTERVAL;;
      9) save_config; break;;
      *) echo "Opção inválida."; sleep 1;;
    esac
  done
}

# Menu principal
main_menu() {
  while true; do
    clear
    echo "===== BackupCraft Minecraft ====="
    echo "[1] Fazer backup"
    echo "[2] Restaurar backup"
    echo "[3] Configurações"
    echo "[4] Iniciar backup automático (em segundo plano)"
    echo "[5] Parar backup automático"
    echo "[6] Limpar backups antigos"
    echo "[7] Sair"
    read -p "Escolha: " choice
    case $choice in
      1) backup_world ;;
      2) restore_backup ;;
      3) config_menu ;;
      4)
        if [[ "$AUTO_BACKUP" == "true" ]]; then
          if [[ -f "$HOME/.backupcraft_autobackup.pid" && -d "/proc/$(cat "$HOME/.backupcraft_autobackup.pid")" ]]; then
            echo -e "${RED}Backup automático já está rodando.${NC}"
          else
            auto_backup_loop &
            echo $! > "$HOME/.backupcraft_autobackup.pid"
            echo "Backup automático iniciado em segundo plano."
          fi
        else
          echo "Backup automático está desativado nas configurações."
        fi
        read -p "Pressione Enter para continuar..."
        ;;
      5)
        if [[ -f "$HOME/.backupcraft_autobackup.pid" ]]; then
          kill $(cat "$HOME/.backupcraft_autobackup.pid") 2>/dev/null
          rm -f "$HOME/.backupcraft_autobackup.pid"
          echo "Backup automático parado."
        else
          echo "Backup automático não está rodando."
        fi
        read -p "Pressione Enter para continuar..."
        ;;
      6) clean_old_backups ;;
      7) echo "Saindo..."; exit 0 ;;
      *) echo "Opção inválida."; sleep 1 ;;
    esac
  done
}

# Programa começa aqui
load_config
main_menu