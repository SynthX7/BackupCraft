#!/bin/bash

clear

# install.sh - Instalador do BackupCraft v1.6.2

# ==== Boas-vindas e aviso ====
echo "========================="
echo " Bem-vindo ao instalador "
echo "     BackupCraft v1.6.2  "
echo "========================="
echo

echo "Se existirem scripts antigos, como 'backupcraft.sh', eles serão removidos automaticamente."
echo "Caso tenha utilizado outras versões, todas as suas configurações serão mantidas, exceto as que tiveram modificações ou foram excluídas."
echo "Sua senha pode ser solicitada durante a instalação caso não execute esse script com 'sudo'"
echo
read -p "Pressione Enter para iniciar a instalação ou Ctrl+C para cancelar..."

# ==== Limpeza de scripts antigos ====
ANTIGOS=("$HOME/backupcraft.sh" "$HOME/install.sh")
for file in "${ANTIGOS[@]}"; do
  if [[ -f "$file" ]]; then
    rm -f "$file"
    echo "Removido script antigo: $file"
  fi
done

# ==== Dependências ====
DEPENDENCIAS=("tar" "gzip" "bzip2" "xz" "bash" "curl" "wget" "zip" "rsync" "find" "7z" "coreutils")
TARFILE="backupcraft.tar.gz"
SCRIPT="bchub.sh"
if [ -n "${SUDO_USER:-}" ]; then
  DESTINO=$(eval echo "~$SUDO_USER")
else
  DESTINO="$HOME"
fi

# Detecta gerenciador de pacotes
if [ -n "${PREFIX:-}" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
  PKG_MANAGER="pkg"
elif command -v apt-get &>/dev/null; then
  PKG_MANAGER="apt-get"
elif command -v dnf &>/dev/null; then
  PKG_MANAGER="dnf"
elif command -v pacman &>/dev/null; then
  PKG_MANAGER="pacman"
else
  echo "[ERRO] Gerenciador de pacotes não suportado automaticamente."
  exit 1
fi

echo "Gerenciador detectado: $PKG_MANAGER"

instalar_pacote() {
  local pacote=$1
  case $PKG_MANAGER in
    pkg)
      pkg install -y "$pacote"
      ;;
    apt-get)
      sudo apt-get update -y
      sudo apt-get install -y "$pacote"
      ;;
    dnf)
      sudo dnf install -y "$pacote"
      ;;
    pacman)
      sudo pacman -Sy --noconfirm "$pacote"
      ;;
  esac
}

for dep in "${DEPENDENCIAS[@]}"; do
  if ! command -v "$dep" &>/dev/null; then
    echo "Dependência '$dep' não encontrada. Instalando..."
    instalar_pacote "$dep"
  else
    echo "Dependência '$dep' já instalada."
  fi
done

# ==== Extração dos arquivos ====
if [[ ! -f "$TARFILE" ]]; then
  echo "[ERRO] Arquivo '$TARFILE' não encontrado no diretório atual."
  exit 1
fi

echo "Extraindo scripts..."
tar -xf "$TARFILE"

# ==== Permissões e movimentação ====
if [[ ! -f "$SCRIPT" ]]; then
  echo "[ERRO] Arquivo $SCRIPT não encontrado após extração."
  exit 1
fi

echo "Aplicando permissões executáveis..."
chmod +x "$SCRIPT"
mv "$SCRIPT" "$DESTINO/"
echo "Script instalado: $DESTINO/$SCRIPT"

# ==== Limpeza do diretório do instalador ====
echo -e "\nInstalação concluída. Gostaria de apagar os arquivos temporários? Isso inclui o .tar.gz que fez o download) (S/n)"
read -rp "Digite: " confirm

case "${confirm,,}" in
s | "")
  echo "Apagando arquivos..."
  if [[ -d "../$TEMP_DIR" ]]; then
    cd ..
    rm -rf "BackupCraft"
  else
    echo "[AVISO] Diretório '$TEMP_DIR' não encontrado. Nenhum arquivo removido."
  fi
  ;;
n)
  ;;
*)
  echo "[AVISO] Entrada inválida. Por favor, responda com 's' ou 'n'. Nenhuma ação tomada."
  ;;
esac

echo "Instalação concluída com sucesso!"
echo "Siga os proximos passos explicados no site"
read -p "Pressione Enter para finalizar..."

# Remove o próprio script
rm -f -- "$0"
clear
