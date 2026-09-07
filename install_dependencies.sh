#!/bin/bash
set -e

echo "=== FLAC2MP3 - Instalación de dependencias ==="
echo ""

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Instalando Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Instalando dependencias con Homebrew..."
brew install ffmpeg chromaprint

echo ""
echo "✅ Dependencias instaladas correctamente"
echo ""
echo "Para instalar la Quick Action en Finder:"
echo "  mkdir -p ~/Library/Services"
echo '  cp -r "FLAC2MP3.app/Contents/Resources/Automator/Send to FLAC2MP3.workflow" ~/Library/Services/'
echo ""
echo "Luego ve a Preferencias del Sistema > Teclado > Atajos > Servicios"
echo "y activa 'Enviar a FLAC2MP3' en Archivos y Carpetas"
