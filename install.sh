#!/bin/bash

# Nome do script a ser instalado
ARQUIVO_ALVO="backupcraft_linux.sh"
DESTINO="$HOME"
ZIPFILE="backupcraft_linux.zip"

# =============================
# DETECTA GERENCIADOR DE PACOTES
# =============================

if [ "$PREFIX" = "/data/data/com.termux/files/usr" ]; then
  echo "Ambiente Termux detectado."
  PKG_MANAGER="pkg"
  INSTALL_CMD="pkg install -y"
else
  if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    INSTALL_CMD="sudo apt-get install -y"
  elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
  elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="sudo pacman -Sy --noconfirm"
  else
    echo "Gerenciador de pacotes não suportado automaticamente."
    exit 1
  fi
fi

echo "Gerenciador detectado: $PKG_MANAGER"

# =============================
# DEFINIR DEPENDÊNCIAS
# =============================

DEPENDENCIAS=("zip" "curl" "wget" "bash" "rsync" "coreutils" "findutils" "unzip")

# Adiciona o pacote correto de p7zip dependendo do ambiente
if [ "$PKG_MANAGER" = "pkg" ]; then
  DEPENDENCIAS+=("p7zip")
else
  DEPENDENCIAS+=("p7zip-full")
fi

# =============================
# INSTALAR DEPENDÊNCIAS
# =============================

for dep in "${DEPENDENCIAS[@]}"; do
  if ! command -v "$dep" &> /dev/null; then
    echo "Dependência $dep não encontrada. Instalando..."
    $INSTALL_CMD "$dep"
  else
    echo "Dependência $dep já instalada."
  fi
done

# =============================
# PROCESSO DE INSTALAÇÃO DO SCRIPT
# =============================

echo "Verificando arquivos do sistema..."
mkdir -p "$DESTINO"

# Verifica se o arquivo zip existe
if [ ! -f "$ZIPFILE" ]; then
  echo "Erro: Arquivo '$ZIPFILE' não encontrado!"
  exit 1
fi

echo "Extraindo script..."
unzip -q "$ZIPFILE"

echo "Aplicando permissão de execução..."
chmod +x "$ARQUIVO_ALVO"

echo "Movendo script para '$DESTINO'..."
mv "$ARQUIVO_ALVO" "$DESTINO/"

# =============================
# LIMPEZA FINAL
# =============================

echo "Excluindo arquivos temporários..."

# Caminho do diretório onde o script está atualmente
DIR_ATUAL="$(dirname "$(realpath "$0")")"

# Sobe um nível na pasta
cd ..

# Remove a pasta do script
rm -rf "$DIR_ATUAL"

echo "Arquivo $ARQUIVO_ALVO movido para $DESTINO e tornado executável."
read -p "Pressione Enter para continuar. Este instalador será removido..."

# Apaga o próprio script de instalação
rm -- "$0"