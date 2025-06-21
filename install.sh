#!/bin/bash

# install.sh - Instalador do BackupCraft v1.6

# ==== Boas-vindas e aviso ====
echo "========================="
echo " Bem-vindo ao instalador "
echo "     BackupCraft v1.6     "
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
ARQUIVOS_SCRIPTS=("bchub.sh" "bcauto.sh")
DESTINO="$HOME"

# Detecta gerenciador de pacotes
if [ -n "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
  PKG_MANAGER="pkg"
elif command -v apt-get &> /dev/null; then
  PKG_MANAGER="apt-get"
elif command -v dnf &> /dev/null; then
  PKG_MANAGER="dnf"
elif command -v pacman &> /dev/null; then
  PKG_MANAGER="pacman"
else
  echo "Gerenciador de pacotes não suportado automaticamente."
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
  if ! command -v "$dep" &> /dev/null; then
    echo "Dependência '$dep' não encontrada. Instalando..."
    instalar_pacote "$dep"
  else
    echo "Dependência '$dep' já instalada."
  fi
done

# ==== Extração dos arquivos ====
echo "Verificando arquivos do sistema..."
mkdir -p "$DESTINO"

echo "Extraindo scripts..."
tar -xf "$TARFILE" || { echo "Falha ao extrair o arquivo TAR."; exit 1; }

echo "Aplicando permissões executáveis..."
for script in "${ARQUIVOS_SCRIPTS[@]}"; do
  chmod +x "$script"
  mv "$script" "$DESTINO/"
  echo "Script instalado: $DESTINO/$script"
done

# ==== Limpeza do diretório do instalador ====
DIR_ATUAL="$(dirname "$(realpath "$0")")"
cd ..
rm -rf "$DIR_ATUAL"

echo "Instalação concluída com sucesso!"
echo "Use 'bchub.sh' para iniciar o BackupCraft."
read -p "Pressione Enter para finalizar..."

# Remove o próprio script
rm -f -- "$0"
