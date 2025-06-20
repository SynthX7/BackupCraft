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
  [[ -f "$CONFIG_FILE" ]] || cat > "$CONFIG_FILE" << EOF
MULTIPLE_BACKUPS=true
REPLACE_ON_RESTORE=false
IGNORE_BACKUP_WORLD=true
ENABLE_HIDDEN_BACKUP=true
ENABLE_ENCRYPTION=false
ENCRYPTION_PASSWORD=""
AUTO_BACKUP=false
AUTO_BACKUP_INTERVAL=600
AUTO_BACKUP_WORLDS=""
EOF
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
AUTO_BACKUP_WORLDS="$AUTO_BACKUP_WORLDS"
EOF
}

# Barra de progresso dinâmica ligada ao processo da compressão
progress_during_compression() {
  local pid=$1       # PID do processo da compressão
  local total_time=$2 # Estimativa de tempo em segundos
  local width=40
  local elapsed=0

  while kill -0 "$pid" 2>/dev/null; do
    local progress=$elapsed
    (( progress > total_time )) && progress=$total_time
    local filled=$(( progress * width / total_time ))
    local empty=$(( width - filled ))
    local remaining=$(( total_time - progress ))
    local percentage=$(( progress * 100 / total_time ))

    local bar="\e[32m["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+=" "; done
    bar+="\e[0m] ${percentage}%"
    bar+=" (${remaining}s restantes)"

    echo -ne "\r$bar"

    sleep 1
    ((elapsed++))
  done

  # Finaliza com 100%
  echo -e "\r\e[32m[${width}█]\e[0m 100% (0s restantes)\n"
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

# Estima tempo de compressão com base no tamanho e nos núcleos da CPU
estimate_time_by_size() {
  local path="$1"  # Caminho do diretório a ser compactado
  local size_bytes=$(du -sb "$path" | cut -f1)
  local cores=$(nproc)
  local speed=$(( cores * 4400000 ))  # 4,4 MB/s por núcleo (estimado)
  local time_sec=$(( size_bytes / speed ))

  # Limite de segurança
  (( time_sec < 5 )) && time_sec=5

  echo "$time_sec"
}

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
      local backup_name="${world}"
      [[ "$MULTIPLE_BACKUPS" == "true" ]] && backup_name="${world} (${timestamp})"

      local world_path="$SAVE_DIR/$world"
      local zip_path="$BACKUP_DIR/$backup_name/${world}.7z"
      mkdir -p "$BACKUP_DIR/$backup_name"

      # Detectar advancements principal
      local advancements_dir="$world_path/advancements"
      local advancements_file=""
      if [[ -d "$advancements_dir" ]]; then
        advancements_file=$(ls "$advancements_dir"/*.json 2>/dev/null | while read f; do
          echo "$(jq '. | length' "$f") $(stat -c %Y "$f") $f"
        done | sort -k1,1n -k2,2nr | head -n1 | awk '{print $3}')
      fi

      # Criar estrutura temporária
      local tmpdir
      tmpdir="$(mktemp -d)"
      mkdir -p "$tmpdir/World"
      cp -r "$world_path/"* "$tmpdir/World/"

      # Adicionar conquistas ao backup
      if [[ -n "$advancements_file" && -f "$advancements_file" ]]; then
        jq '.' "$advancements_file" > "$tmpdir/advancements.txt"
      fi

      echo "Iniciando compressão do backup..."

      # Iniciar compressão em segundo plano
      (
        cd "$tmpdir" || exit
        if [[ "$ENABLE_ENCRYPTION" == "true" && -n "$ENCRYPTION_PASSWORD" ]]; then
          7z a -t7z -p"$ENCRYPTION_PASSWORD" -mhe=on "$zip_path" . > /dev/null
        else
          7z a -t7z "$zip_path" . > /dev/null
        fi
      ) &
      local compress_pid=$!

      # Estimar tempo com base no tamanho
      local time_sec
      time_sec=$(estimate_time_by_size "$tmpdir")

      # Mostrar barra de progresso
      progress_during_compression "$compress_pid" "$time_sec"

      wait "$compress_pid"
      rm -rf "$tmpdir"

      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Backup criado com sucesso em: $zip_path${NC}"
        log_action "Backup criado: $backup_name/${world}.7z"
      else
        echo -e "${RED}Erro ao criar o backup.${NC}"
        log_action "Erro ao criar backup: $backup_name/${world}.7z"
        read -p "Pressione Enter para continuar..."
        return
      fi

      if [[ "$ENABLE_HIDDEN_BACKUP" == "true" ]]; then
        echo "Criando backup oculto..."
        mkdir -p "$HIDDEN_BACKUP_DIR"
        cp -r "$world_path" "$HIDDEN_BACKUP_DIR/${world}_hidden"
        log_action "Backup oculto criado: ${world}_hidden"
      fi

      read -p "Backup finalizado. Pressione Enter para continuar..."
      return
    else
      echo "Opção inválida."
    fi
  done
}


# Restayura as conquistas
restore_advancements() {
  mapfile -t worlds < <(list_worlds)
  if [ ${#worlds[@]} -eq 0 ]; then
    echo -e "${RED}Nenhum mundo válido encontrado.${NC}"
    read -p "Pressione Enter para continuar..."
    return
  fi

  echo "===== Selecionar Mundo para Restaurar Conquistas ====="
  select world in "${worlds[@]}" "Voltar"; do
    [[ "$REPLY" == $((${#worlds[@]}+1)) || "$world" == "Voltar" ]] && return
    if [[ -n "$world" ]]; then
      local advancements_dir="$SAVE_DIR/$world/advancements"
      if [[ ! -d "$advancements_dir" ]]; then
        echo -e "${RED}Pasta de conquistas não encontrada no mundo selecionado.${NC}"
        read -p "Pressione Enter para continuar..."
        return
      fi

      echo "Analisando arquivos de conquistas em \"$advancements_dir\"..."

      # Encontrar arquivo com maior número de conquistas e mais antigo (em caso de empate)
      local best_file=""
      local current_file=""
      local max_count=-1
      local min_count=999999
      local newest_time=0
      local oldest_time=9999999999

      while IFS= read -r -d '' file; do
        local count=$(jq '. | length' "$file")
        local mod_time=$(stat -c %Y "$file")

        # Melhor arquivo (mais conquistas, mais antigo)
        if (( count > max_count )) || { (( count == max_count )) && (( mod_time < oldest_time )); }; then
          max_count=$count
          oldest_time=$mod_time
          best_file="$file"
        fi

        # Atual presumido (menos conquistas, mais recente)
        if (( count < min_count )) || { (( count == min_count )) && (( mod_time > newest_time )); }; then
          min_count=$count
          newest_time=$mod_time
          current_file="$file"
        fi
      done < <(find "$advancements_dir" -name "*.json" -print0)

      if [[ -z "$best_file" || -z "$current_file" ]]; then
        echo -e "${RED}Não foi possível identificar os arquivos necessários para restauração.${NC}"
        read -p "Pressione Enter para continuar..."
        return
      fi

      echo "🟢 Restaurando conquistas:"
      echo "📦 De: \"$best_file\""
      echo "➡️ Para: \"$current_file\""

      jq '.' "$best_file" > "$current_file"

      if [[ "$best_file" != "$current_file" ]]; then
        rm -f "$best_file"
        echo "🧹 Arquivo antigo removido: \"$best_file\""
      fi

      echo -e "${GREEN}Conquistas restauradas com sucesso.${NC}"
      read -p "Pressione Enter para continuar..."
      return
    else
      echo "Opção inválida."
    fi
  done
}





# Restaura o backup automaticamente
restore_backup() {
  mapfile -t backups < <(list_backups)
  if [ ${#backups[@]} -eq 0 ]; then
    echo -e "${RED}Nenhum backup disponível.${NC}"
    read -p "Pressione Enter para continuar..."
    return
  fi

  echo "===== Backups Disponíveis ====="
  select backup in "${backups[@]}" "Voltar"; do
    [[ "$REPLY" == $((${#backups[@]}+1)) || "$backup" == "Voltar" ]] && return
    if [[ -n "$backup" ]]; then
      local backup_path="$BACKUP_DIR/$backup"
      local archive=$(find "$backup_path" -name "*.7z" | head -n 1)
      local world_name=$(basename "$archive" .7z)

      [[ ! -f "$archive" ]] && echo -e "${RED}Arquivo de backup não encontrado.${NC}" && return

      echo "Extraindo backup..."
      tmpdir="$(mktemp -d)"
      if [[ "$ENABLE_ENCRYPTION" == "true" && -n "$ENCRYPTION_PASSWORD" ]]; then
        7z x -p"$ENCRYPTION_PASSWORD" "$archive" -o"$tmpdir" >/dev/null
      else
        7z x "$archive" -o"$tmpdir" >/dev/null
      fi

      [[ $? -ne 0 ]] && echo -e "${RED}Erro ao extrair o backup.${NC}" && rm -rf "$tmpdir" && return

      # Substituir mundo atual
      local target_path="$SAVE_DIR/$world_name"
      echo -e "${YELLOW}⚠️ O mundo atual será substituído.${NC}"
      read -p "Deseja continuar? (s/n): " confirm
      [[ "$confirm" != "s" ]] && echo "Cancelado." && rm -rf "$tmpdir" && return

      rm -rf "$target_path"
      mkdir -p "$target_path"
      cp -r "$tmpdir/World/"* "$target_path/"

      echo -e "${GREEN}✅ Mundo restaurado com sucesso.${NC}"
      log_action "Mundo restaurado: $world_name"

      rm -rf "$tmpdir"
      read -p "Pressione Enter para continuar..."
      return
    else
      echo "Opção inválida."
    fi
  done
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
    echo "===== Configurações Gerais ====="
    echo "[1] Backups versionados: $MULTIPLE_BACKUPS"
    echo "[2] Substituir mundo ao restaurar: $REPLACE_ON_RESTORE"
    echo "[3] Ignorar mundos restaurados (BackupCraft): $IGNORE_BACKUP_WORLD"
    echo "[4] Backup oculto extra: $ENABLE_HIDDEN_BACKUP"
    echo "[5] Criptografia: $ENABLE_ENCRYPTION"
    echo "[6] Senha de criptografia: $( [[ -n \"$ENCRYPTION_PASSWORD\" ]] && echo \"Definida\" || echo \"Não definida\" )"
    echo "[7] Voltar"
    read -p "Escolha: " opt
    case $opt in
      1) MULTIPLE_BACKUPS=$( [[ "$MULTIPLE_BACKUPS" == "true" ]] && echo "false" || echo "true" );;
      2) REPLACE_ON_RESTORE=$( [[ "$REPLACE_ON_RESTORE" == "true" ]] && echo "false" || echo "true" );;
      3) IGNORE_BACKUP_WORLD=$( [[ "$IGNORE_BACKUP_WORLD" == "true" ]] && echo "false" || echo "true" );;
      4) ENABLE_HIDDEN_BACKUP=$( [[ "$ENABLE_HIDDEN_BACKUP" == "true" ]] && echo "false" || echo "true" );;
      5) ENABLE_ENCRYPTION=$( [[ "$ENABLE_ENCRYPTION" == "true" ]] && echo "false" || echo "true" );;
      6) read -s -p "Digite a nova senha: " ENCRYPTION_PASSWORD; sleep 1 ;;
      7) save_config; break;;
      *) echo "Opção inválida."; sleep 1;;
    esac
  done
}

formatar_tempo() {
  local s=$1
  if ((s < 60)); then echo "$s segundos"
  elif ((s < 3600)); then echo "$((s / 60)) minutos"
  else echo "$((s / 3600))h $(((s % 3600) / 60))m"; fi
}

bcauto_config_menu() {
  while true; do
    clear
    echo "===== Configuração do Backup Automático ====="
    echo "[1] Selecionar mundos (atual: $AUTO_BACKUP_WORLDS)"
    echo "[2] Frequência: $(formatar_tempo $AUTO_BACKUP_INTERVAL)"
    echo "[3] $( [[ "$AUTO_BACKUP" == "true" ]] && echo "Desativar" || echo "Ativar" ) backup automático (status: $AUTO_BACKUP)"
    echo "[4] Executar agora (terminal deve permanecer aberto)"
    echo "[5] Voltar"
    read -p "> " opt
    case $opt in
      1)
        mapfile -t worlds < <(list_worlds)
        selecionados=()
        while true; do
          clear
          echo "- Selecione mundos para auto-backup (Digite 'b' para sair) -"
          for i in "${!worlds[@]}"; do
            mundo="${worlds[$i]}"
            if [[ " $AUTO_BACKUP_WORLDS " == *"$mundo"* ]]; then
              echo "$((i+1))) $mundo [✓]"
            else
              echo "$((i+1))) $mundo"
            fi
          done
          read -p "> " sel
          if [[ "$sel" == "b" ]]; then break
          elif [[ "$sel" =~ ^[0-9]+$ && $sel -ge 1 && $sel -le ${#worlds[@]} ]]; then
            mundo_selecionado="${worlds[$((sel-1))]}"
            if [[ " $AUTO_BACKUP_WORLDS " == *"$mundo_selecionado"* ]]; then
              AUTO_BACKUP_WORLDS=$(echo "$AUTO_BACKUP_WORLDS" | sed "s/\b$mundo_selecionado\b//g")
            else
              AUTO_BACKUP_WORLDS+=" $mundo_selecionado"
            fi
          fi
        done
        echo -e "Salvo!"; sleep 1 ;;
      2)
        read -p "Digite o intervalo em segundos: " AUTO_BACKUP_INTERVAL
        echo -e "Salvo!"; sleep 1 ;;
      3)
        AUTO_BACKUP=$( [[ "$AUTO_BACKUP" == "true" ]] && echo "false" || echo "true" )
        echo -e "Salvo!"; sleep 1 ;;
      4)
        if [[ "$AUTO_BACKUP" == "true" ]]; then
          echo "Backup automático ativo. Pressione Ctrl+C para parar."
          while true; do
            for mundo in $AUTO_BACKUP_WORLDS; do
              backup_world_auto "$mundo"
            done
            sleep "$AUTO_BACKUP_INTERVAL"
          done
        else
          echo "Backup automático está desativado nas configurações."
          sleep 2
        fi ;;
      5) save_config; break;;
      *) echo "Opção inválida."; sleep 1;;
    esac
  done
}

confirm_bcauto() {
  echo "Tem certeza que deseja executar o backup automático? (S/n)"
  read -p "Digite: " confirm

  case "$confirm" in
    [sS]|"")
      echo "✔ Iniciando backup automático..."
      ./bcauto.sh
      ;;
    [nN])
      echo "${RED}Backup automático cancelado pelo usuário.${NC}"
      main_menu
      ;;
    *)
      echo "Entrada inválida. Por favor, responda com S ou N."
      confirm_bcauto 
      ;;
  esac

}


# Menu principal
main_menu() {
  while true; do
    clear
    echo "===== BackupCraft ====="
    echo "[1] Fazer backup"
    echo "[2] Restaurar backup"
    echo "[3] Restaurar conquistas"
    echo "[4] Configurações gerais"
    echo "[5] Configurações backup automático"
    echo "[6] Iniciar backup automático"
    echo "[7] Sair"
    read -p "Escolha: " choice
    case $choice in
      1) backup_world ;;
      2) restore_backup ;;
      3) restore_advancements ;;
      4) config_menu ;;
      5) bcauto_config_menu ;; # novo menu exclusivo para configurações automáticas
      6) confirm_bcauto ;;
      7) echo "Saindo..."; exit 0 ;;
      *) echo "Opção inválida."; sleep 1 ;;
    esac
  done
}

# Programa começa aqui
load_config
main_menu