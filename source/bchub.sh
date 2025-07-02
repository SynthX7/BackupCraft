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
if ! command -v 7z &>/dev/null; then
  echo -e "${RED}Erro: 7zip não está instalado. Instale-o com 'sudo apt install p7zip-full' ou equivalente para sua distribuição.${NC}"
  exit 1
fi

# Função de log
log_action() {
  local message="$1"
  echo "[$(date +"%d/%m/%Y %H:%M:%S")] $message" >>"$LOG_FILE"
}

# Carregar configurações
load_config() {
  [[ -f "$CONFIG_FILE" ]] || cat >"$CONFIG_FILE" <<EOF
BACKUP_MODE=""
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
  {
    echo "BACKUP_MODE=$BACKUP_MODE"
    echo "MULTIPLE_BACKUPS=$MULTIPLE_BACKUPS"
    echo "REPLACE_ON_RESTORE=$REPLACE_ON_RESTORE"
    echo "IGNORE_BACKUP_WORLD=$IGNORE_BACKUP_WORLD"
    echo "ENABLE_HIDDEN_BACKUP=$ENABLE_HIDDEN_BACKUP"
    echo "ENABLE_ENCRYPTION=$ENABLE_ENCRYPTION"
    echo "ENCRYPTION_PASSWORD=\"$ENCRYPTION_PASSWORD\""
    echo "AUTO_BACKUP=$AUTO_BACKUP"
    echo "AUTO_BACKUP_INTERVAL=$AUTO_BACKUP_INTERVAL"

    # Salvar mundos como array
    echo "AUTO_BACKUP_WORLDS=("
    for world in "${AUTO_BACKUP_WORLDS[@]}"; do
      echo "  \"${world}\""
    done
    echo ")"
  } >"$CONFIG_FILE"
}

# Barra de progresso dinâmica ligada ao processo da compressão
progress_during_compression() {
  local pid=$1   # PID do processo em segundo plano
  local width=20 # Tamanho da barra visual

  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    local bar=""
    for ((j = 0; j < width; j++)); do
      if ((j < (i % (width + 1)))); then
        bar+="▰"
      else
        bar+="▱"
      fi
    done
    echo -ne "\r\e[32m[$bar ]\e[0m"
    sleep 0.15
    ((i++))
  done

  echo -e "\r\e[32m[▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰ ]\e[0m\n"
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
  local path="$1" # Caminho do diretório a ser compactado
  local size_bytes=$(du -sb "$path" | cut -f1)
  local cores=$(nproc)
  local base_speed=5000000 # 5 MB/s por core (ajuste conforme necessário)
  local total_speed=$((cores * base_speed))
  local time_sec=$((size_bytes / total_speed))

  # Limite de segurança
  ((time_sec < 5)) && time_sec=5

  echo "$time_sec"
}

backup_world() {
  local world="$1"
  local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  local backup_name="$world"
  [[ "$MULTIPLE_BACKUPS" == "true" ]] && backup_name="${world} (${timestamp})"

  local world_path="$SAVE_DIR/$world"
  local backup_dir="$BACKUP_DIR/$backup_name"
  local zip_path="$backup_dir/${world}.7z"
  mkdir -p "$backup_dir"

  # === Selecionar advancements principal ===
  local advancements_file=""
  local advancements_dir="$world_path/advancements"
  if [[ -d "$advancements_dir" ]]; then
    advancements_file=$(find "$advancements_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | while IFS= read -r f; do
      count=$(jq '. | length' "$f" 2>/dev/null || echo 0)
      modtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
      echo "$count $modtime $f"
    done | sort -k1,1nr -k2,2nr | head -n1 | cut -d' ' -f3-)
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/World"
  cp -r "$world_path/"* "$tmpdir/World/" 2>/dev/null

  if [[ "$ENABLE_ENCRYPTION" == "true" && -z "$ENCRYPTION_PASSWORD" ]]; then
    echo -e "${RED}Erro: Criptografia ativada, mas nenhuma senha definida.${NC}"
    rm -rf "$tmpdir"
    read -p "Pressione Enter para continuar..."
    return
  fi

  rm -f "$zip_path"

  echo "Iniciando compressão do backup... (Isso pode demorar um pouco, não cancele)"
  pushd "$tmpdir" >/dev/null || return
  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    7z a $ARGS -p"$ENCRYPTION_PASSWORD" -mhe=on "$zip_path" . >/dev/null &
  else
    7z a $ARGS "$zip_path" . >/dev/null &
  fi

  local compress_pid=$!
  popd >/dev/null
  local time_sec
  time_sec=$(estimate_time_by_size "$tmpdir")
  progress_during_compression "$compress_pid"
  wait "$compress_pid"
  local backup_status=$?
  rm -rf "$tmpdir"

  # === Backup das conquistas ===
  if [[ -n "$advancements_file" ]]; then
    local adv_dir="$HIDDEN_BACKUP_DIR/${world}_conquistas"
    mkdir -p "$adv_dir"
    local adv_txt="$adv_dir/advancements.txt"
    jq '.' "$advancements_file" >"$adv_txt" 2>/dev/null

    local adv_zip="$adv_dir/${world}_conquistas.7z"
    rm -f "$adv_zip"

    pushd "$adv_dir" >/dev/null || return
    if [[ "$ENABLE_ENCRYPTION" == "true" && -n "$ENCRYPTION_PASSWORD" ]]; then
      7z a -t7z -p"$ENCRYPTION_PASSWORD" -mhe=on "$adv_zip" advancements.txt >/dev/null
    else
      7z a -t7z "$adv_zip" advancements.txt >/dev/null
    fi
    rm -f advancements.txt
    popd >/dev/null
  fi

  if [[ "$backup_status" -ne 0 ]]; then
    echo -e "${RED}Erro ao criar o backup.${NC}"
    log_action "Erro ao criar backup: $backup_name/${world}.7z"
    read -p "Pressione Enter para continuar..."
    return
  fi

  echo -e "${GREEN}Backup criado com sucesso em: $zip_path${NC}"
  log_action "Backup criado: $backup_name/${world}.7z"

  # === Backup oculto ===
  if [[ "$ENABLE_HIDDEN_BACKUP" == "true" ]]; then
    echo "Backup principal finalizado"
    echo "Criando backup oculto... (Isso pode demorar um pouco, não cancele)"

    local hidden_dir="$HIDDEN_BACKUP_DIR/${world}_hidden"
    rm -rf "$hidden_dir"
    mkdir -p "$HIDDEN_BACKUP_DIR"
    cp -r "$world_path" "$hidden_dir"

    local hidden_zip="$HIDDEN_BACKUP_DIR/${world}_hidden.7z"
    rm -f "$hidden_zip"

    pushd "$HIDDEN_BACKUP_DIR" >/dev/null || return

    # Inicia compressão em segundo plano
    if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
      7z a $ARGS -p"$ENCRYPTION_PASSWORD" -mhe=on "$hidden_zip" "${world}_hidden" >/dev/null &
    else
      7z a $ARGS "$hidden_zip" "${world}_hidden" >/dev/null &
    fi

    local compress_pid=$!
    progress_during_compression "$compress_pid"
    wait "$compress_pid"
    local backup_status=$?

    popd >/dev/null
    rm -rf "$hidden_dir"

    log_action "Backup oculto criado: ${world}_hidden"
  fi

  echo "[INFO] Se suas conquistas forem resetadas, tente restaurar na opção 'Restaurar conquistas' no menu principal"
  read -p "Backup finalizado. Pressione Enter para continuar..."
}

select_world() {
  mapfile -t worlds < <(list_worlds)
  if [ ${#worlds[@]} -eq 0 ]; then
    echo -e "${RED}Nenhum mundo válido encontrado para backup.${NC}"
    read -p "Pressione Enter para continuar..."
    return 1
  fi

  echo "===== Mundos Disponíveis ====="
  select world in "${worlds[@]}" "Voltar"; do
    if [[ "$REPLY" == $((${#worlds[@]} + 1)) || "$world" == "Voltar" ]]; then
      return 1
    fi
    if [[ -n "$world" ]]; then
      base_speed=2000000
      ARGS="-t7z"
      selected_world="$world" # ← salva em variável global
      return 0
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
    [[ "$REPLY" == $((${#worlds[@]} + 1)) || "$world" == "Voltar" ]] && return
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
        if ((count > max_count)) || { ((count == max_count)) && ((mod_time < oldest_time)); }; then
          max_count=$count
          oldest_time=$mod_time
          best_file="$file"
        fi

        # Atual presumido (menos conquistas, mais recente)
        if ((count < min_count)) || { ((count == min_count)) && ((mod_time > newest_time)); }; then
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

      jq '.' "$best_file" >"$current_file"

      if [[ "$best_file" != "$current_file" ]]; then
        rm -f "$best_file"
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
    [[ "$REPLY" == $((${#backups[@]} + 1)) || "$backup" == "Voltar" ]] && return
    if [[ -n "$backup" ]]; then
      local backup_path="$BACKUP_DIR/$backup"
      local archive
      archive=$(find "$backup_path" -name "*.7z" | head -n 1)
      local world_name
      world_name=$(basename "$archive" .7z)

      if [[ ! -f "$archive" ]]; then
        echo -e "${RED}Arquivo de backup não encontrado.${NC}"
        return
      fi

      local tmpdir
      tmpdir="$(mktemp -d)"

      # Tenta extrair com senha padrão vazia
      7z x -p"" "$archive" -o"$tmpdir" >/dev/null 2>&1
      if [[ $? -ne 0 ]]; then
        # Backup é criptografado
        echo -e "${YELLOW}Este backup está criptografado.${NC}"
        local input_password=""
        read -rsp "Digite a senha do backup: " input_password
        echo
        rm -rf "$tmpdir"
        tmpdir="$(mktemp -d)"
        7z x -p"$input_password" "$archive" -o"$tmpdir" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
          echo -e "${RED}Erro: senha incorreta ou falha na extração.${NC}"
          rm -rf "$tmpdir"
          read -p "Pressione Enter para continuar..."
          return
        fi
      fi

      # Definir nome e destino do mundo restaurado

      if [[ "$REPLACE_ON_RESTORE" == "true" ]]; then
        target_name="$world_name"
        replace="(Irá substituir o mundo atual)"
      else
        target_name="${world_name} (BackupCraft)"
        replace=""
      fi

      local target_path="$SAVE_DIR/$target_name"

      echo -e "${YELLOW}⚠️ O mundo será restaurado como: '$target_name' $replace.${NC}"
      read -p "Deseja continuar? (s/n): " confirm
      [[ "$confirm" != "s" ]] && echo "Cancelado." && rm -rf "$tmpdir" && return

      rm -rf "$target_path"
      mkdir -p "$target_path"
      cp -r "$tmpdir/World/"* "$target_path/"

      echo -e "${GREEN}✅ Mundo restaurado como '$target_name' com sucesso.${NC}"
      log_action "Mundo restaurado: $target_name"

      rm -rf "$tmpdir"
      read -p "Pressione Enter para continuar..."
      return
    else
      echo "Opção inválida."
    fi
  done
}

# Menu de configurações
config_menu() {
  while true; do
    clear
    echo "===== Configurações Gerais ====="
    echo "[1] Backups versionados: $MULTIPLE_BACKUPS"
    echo "[2] Substituir mundo ao restaurar: $REPLACE_ON_RESTORE"
    echo "[3] Ignorar mundos restaurados (com 'BackupCraft' no nome): $IGNORE_BACKUP_WORLD"
    echo "[4] Backup oculto extra: $ENABLE_HIDDEN_BACKUP"
    echo "[5] Criptografia: $ENABLE_ENCRYPTION"
    if [[ -z "$ENCRYPTION_PASSWORD" ]]; then
      echo '[6] Senha de criptografia: "Não definida"'
    else
      echo '[6] Senha de criptografia: "Definida"'
    fi

    echo "[7] Voltar"
    read -p "Escolha: " opt
    case $opt in
    1) MULTIPLE_BACKUPS=$([[ "$MULTIPLE_BACKUPS" == "true" ]] && echo "false" || echo "true") ;;
    2) REPLACE_ON_RESTORE=$([[ "$REPLACE_ON_RESTORE" == "true" ]] && echo "false" || echo "true") ;;
    3) IGNORE_BACKUP_WORLD=$([[ "$IGNORE_BACKUP_WORLD" == "true" ]] && echo "false" || echo "true") ;;
    4) ENABLE_HIDDEN_BACKUP=$([[ "$ENABLE_HIDDEN_BACKUP" == "true" ]] && echo "false" || echo "true") ;;
    5) ENABLE_ENCRYPTION=$([[ "$ENABLE_ENCRYPTION" == "true" ]] && echo "false" || echo "true") ;;
    6)
      read -s -p "Digite a nova senha: " ENCRYPTION_PASSWORD
      sleep 1
      ;;
    7)
      save_config
      break
      ;;
    *)
      echo "Opção inválida."
      sleep 1
      ;;
    esac
  done
}

formatar_tempo() {
  local s=$1
  local unit
  local value

  if ((s < 60)); then
    value=$s
    unit="segundo"
  elif ((s < 3600)); then
    value=$((s / 60))
    unit="minuto"
  elif ((s < 86400)); then
    value=$((s / 3600))
    unit="hora"
  elif ((s < 604800)); then
    value=$((s / 86400))
    unit="dia"
  elif ((s < 2592000)); then # 30 dias aproximadamente
    value=$((s / 604800))
    unit="semana"
  elif ((s < 31536000)); then # 365 dias aproximadamente
    value=$((s / 2592000))
    unit="mês"
  else
    value=$((s / 31536000))
    unit="ano"
  fi

  # Pluraliza a unidade se value for diferente de 1
  if ((value == 1)); then
    echo "1 $unit"
  else
    # para plural, geralmente basta adicionar 's' no português, exceto "mês" que vira "meses"
    if [[ "$unit" == "mês" ]]; then
      echo "$value meses"
    else
      echo "$value ${unit}s"
    fi
  fi
}

bcauto_config_menu() {
  while true; do
    clear
    echo "===== Configuração do Backup Automático ====="
    echo "[1] Selecionar mundos"

    if [[ ("$value" -ge 10 && "$unit" == "minuto") || (\
      "$value" -ge 1 && "$unit" == "hora") || (\
      "$value" -ge 1 && "$unit" == "dia") || (\
      "$value" -ge 1 && "$unit" == "mês") || (\
      "$value" -ge 1 && "$unit" == "ano") ]]; then

      echo "[2] Frequência: $(formatar_tempo "$AUTO_BACKUP_INTERVAL") <- Lembre-se que backup de mundos grandes podem levar de 1 à 5 minutos."
    else

      echo "[2] Frequência: $(formatar_tempo "$AUTO_BACKUP_INTERVAL")"
    fi

    if [[ -z "$BACKUP_MODE" ]]; then
      mode_text="indefinido"
    elif [[ "$BACKUP_MODE" == "minimo" ]]; then
      mode_text="Desempenho mínimo"
    elif [[ "$BACKUP_MODE" == "medio" ]]; then
      mode_text="Desempenho médio"
    elif [[ "$BACKUP_MODE" == "maximo" ]]; then
      mode_text="Desempenho máximo"
    else
      mode_text="inválido"
    fi

    echo "[3] Modo de desempenho do backup automático: $mode_text"

    echo "[4] Voltar"
    read -p "> " opt
    case "$opt" in
    1)
      mapfile -t worlds < <(list_worlds)
      declare -A selecionados_map
      for mundo in "${AUTO_BACKUP_WORLDS[@]}"; do
        selecionados_map["$mundo"]=1
      done

      while true; do
        clear
        echo "- Selecione mundos para auto-backup (Digite 'b' para sair) -"
        for i in "${!worlds[@]}"; do
          mundo="${worlds[$i]}"
          if [[ ${selecionados_map["$mundo"]} ]]; then
            echo "$((i + 1))) $mundo [✓]"
          else
            echo "$((i + 1))) $mundo"
          fi
        done

        read -p "> " sel
        if [[ "$sel" == "b" ]]; then
          break
        elif [[ "$sel" =~ ^[0-9]+$ && $sel -ge 1 && $sel -le ${#worlds[@]} ]]; then
          mundo_sel="${worlds[$((sel - 1))]}"
          if [[ ${selecionados_map["$mundo_sel"]} ]]; then
            unset 'selecionados_map["'"$mundo_sel"'"]'
          else
            selecionados_map["$mundo_sel"]=1
          fi
        fi
      done

      # Atualizar o array principal com as seleções
      AUTO_BACKUP_WORLDS=()
      for mundo in "${!selecionados_map[@]}"; do
        AUTO_BACKUP_WORLDS+=("$mundo")
      done

      echo -e "Salvo!"
      sleep 1
      ;;
    2)
      read -p "Digite o intervalo em segundos: " AUTO_BACKUP_INTERVAL
      echo -e "Salvo!"
      sleep 1
      ;;
    3)
      echo "Selecione o modo de desempenho:"
      echo "[1] Desempenho mínimo"
      echo "[2] Desempenho médio"
      echo "[3] Desempenho máximo"
      read -rp "Escolha: " escolha_modo
      case "$escolha_modo" in
      1) BACKUP_MODE="minimo" ;;
      2) BACKUP_MODE="medio" ;;
      3) BACKUP_MODE="maximo" ;;
      *) echo "Opção inválida." && sleep 1 ;;
      esac
      ;;
    4)
      save_config
      break
      ;;
    *)
      echo "Opção inválida."
      sleep 1
      ;;
    esac
  done
}

countdown_timer() {
  local total_seconds="$1"
  while [ "$total_seconds" -gt 0 ]; do
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))
    printf "\rPróximo backup automático em: %02d:%02d:%02d" $hours $minutes $seconds
    sleep 1
    ((total_seconds--))
  done
  echo ""
}

executar_backup_automatico() {
  echo -e "[INFO] Modo de desempenho: ${YELLOW}$BACKUP_MODE${NC}"

  # Ctrl+C → voltar ao menu principal
  trap 'echo -e "\n${RED}✘ Backup automático interrompido pelo usuário.${NC}"; sleep 1; exit; exit 0' SIGINT

  load_config

  if [[ -z "$AUTO_BACKUP_WORLDS" ]]; then
    echo -e "${RED}Nenhum mundo configurado para o backup automático.${NC}"
    sleep 2
    ./bchub.sh
    return
  fi

  if [[ -z "$AUTO_BACKUP_INTERVAL" ]]; then
    echo -e "${RED}Intervalo de backup automático não configurado.${NC}"
    sleep 2
    ./bchub.sh
    return
  fi

  readarray -t worlds <<<"$AUTO_BACKUP_WORLDS"

  while true; do
    for world in "${worlds[@]}"; do
      echo -e "\n[INFO] Iniciando backup automático do mundo: ${CYAN}$world${NC}"
      backup_world "$world"
    done

    echo -e "${GREEN}✔ Todos os backups foram concluídos.${NC}"
    countdown_timer "$AUTO_BACKUP_INTERVAL"
  done
}

confirm_bcauto() {
  echo -e "\nTem certeza que deseja executar o backup automático agora? (S/n)"
  read -rp "Digite: " confirm

  case "$BACKUP_MODE" in
  "minimo")
    ARGS="-t7z -mx=1 -mmt=on"
    base_speed=2000000
    ;;
  "medio")
    ARGS="-t7z -mx=5 -mmt=on"
    base_speed=1500000
    ;;
  "maximo")
    ARGS="-t7z -mx=9 -mmt=off"
    base_speed=8000000
    ;;
  *)
    ARGS="-t7z -mx=1 -mmt=on"
    base_speed=2000000
    ;;
  esac

  case "${confirm,,}" in
  s | "")
    base_speed=1000000
    echo "✔ Iniciando backup automático..."
    sleep 1
    yes "" | executar_backup_automatico
    ;;
  n)
    echo -e "${RED}❌ Backup automático cancelado pelo usuário.${NC}"
    sleep 1
    main_menu
    ;;
  *)
    echo "Entrada inválida. Por favor, responda com 's' para sim ou 'n' para não."
    sleep 1
    confirm_bcauto
    ;;
  esac
}

# Menu principal
main_menu() {
  while true; do
    clear
    echo "===== BackupCraft Hub 1.6.3 ====="
    echo "[1] Fazer backup"
    echo "[2] Restaurar backup"
    echo "[3] Restaurar conquistas"
    echo "[4] Configurações gerais"
    echo "[5] Configurações backup automático"
    echo "[6] Iniciar backup automático"
    echo "[7] Sair"
    read -p "Escolha: " choice
    case $choice in
    1)
      select_world
      if [[ $? -eq 0 && -n "$selected_world" ]]; then
        echo "Mundo selecionado: '$selected_world'"
        backup_world "$selected_world"
      else
        echo "❌ Nenhum mundo foi selecionado. Operação cancelada."
      fi

      ;;
    2) restore_backup ;;
    3) restore_advancements ;;
    4) config_menu ;;
    5) bcauto_config_menu ;;
    6) confirm_bcauto ;;
    7)
      echo "Saindo..."
      exit 0
      ;;
    *)
      echo "Opção inválida."
      sleep 1
      ;;
    esac
  done
}

# Programa começa aqui
load_config
main_menu
