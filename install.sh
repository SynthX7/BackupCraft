#!/bin/bash

# Dependências necessárias
DEPENDENCIAS=("tar" "gzip" "bzip2" "xz" "bash" "curl" "wget" "zip" "rsync" "find" "7z" "coreutils")

# Arquivo alvo
ARQUIVO_ALVO="backupcraft_linux.sh"
DESTINO="$HOME"
TARFILE="backupcraft.tar.gz"

# Detecta se está no Termux
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

echo "Verificando arquivos do sistema..."
mkdir -p "$DESTINO"

echo "Extraindo script..."
tar -xf "$TARFILE" || { echo "Falha ao extrair o arquivo TAR."; exit 1; }

echo "Aplicando licença..."
chmod +x "$ARQUIVO_ALVO"

echo "Movendo script para '$DESTINO'..."
mv "$ARQUIVO_ALVO" "$DESTINO/"

echo "Excluindo arquivos temporários..."
# Caminho absoluto do script atual
DIR_ATUAL="$(dirname "$(realpath "$0")")"

# Sobe para o diretório pai e remove a pasta do script
cd ..
rm -rf "$DIR_ATUAL"

echo "Arquivo '$ARQUIVO_ALVO' movido para '$DESTINO' e tornado executável."
read -p "Pressione Enter para continuar, este arquivo irá se auto destruir."

# Remove o próprio script
rm -f -- "$0"
