#!/bin/bash

# Dependências necessárias
DEPENDENCIAS=("zip" "curl" "wget" "p7zip-full" "bash" "rsync" "coreutils" "findutils" "")

# Arquivo alvo para tornar executável e mover
ARQUIVO_ALVO="backupcraft_linux.sh"
DESTINO="$HOME"
ZIPFILE="backupcraft_linux.zip"

# Detecta gerenciador de pacotes
if command -v apt-get &> /dev/null; then
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
    echo "Dependência $dep não encontrada. Instalando..."
    instalar_pacote "$dep"
  else
    echo "Dependência $dep já instalada."
  fi
done

echo "Verificando arquivos do sistema..."
mkdir -p "$DESTINO"

echo "Extraindo script..."
unzip -q "$ZIPFILE"

echo "Aplicando licença..."
chmod +x "$ARQUIVO_ALVO"

echo "Movendo script para '$DESTINO'..."
mv "$ARQUIVO_ALVO" "$DESTINO/"

echo "Excluindo arquivos inúteis..."
# Pega o caminho absoluto da pasta onde está o script
DIR_ATUAL="$(dirname "$(realpath "$0")")"

# Sobe para o diretório pai
cd ..

# Remove a pasta onde o script estava
rm -rf "$DIR_ATUAL"

echo "Arquivo $ARQUIVO_ALVO movido para $DESTINO e tornado executável."
read -p "Pressione Enter para continuar, este arquivo irá se auto destruir."

# Apaga o próprio script de instalação
rm -- "$0"
