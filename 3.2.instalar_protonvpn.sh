#!/bin/bash

# Script de Instalação e Configuração do ProtonVPN CLI no Debian 12
# Autor: Seu Nome
# Versão: 1.0

# Variáveis
PROTONVPN_DEB_URL="https://protonvpn.com/download/protonvpn-stable-release_1.0.8_all.deb"
PROTONVPN_USER=""  # Você pode definir seu nome de usuário ProtonVPN aqui se quiser automatizar o login

echo "==============================================="
echo "    Instalação do ProtonVPN CLI - Debian 12"
echo "==============================================="

# 1. Atualizar o Sistema
echo "[1/9] Atualizando o sistema..."
sudo apt update && sudo apt upgrade -y

# 2. Instalar Dependências
echo "[2/9] Instalando dependências (python3-pip, curl)..."
sudo apt install -y python3-pip curl

# 3. Adicionar Repositório ProtonVPN (tentativa com pacote .deb)
echo "[3/9] Instalando repositório oficial do ProtonVPN..."
wget -q -O protonvpn.deb "$PROTONVPN_DEB_URL"
sudo dpkg -i protonvpn.deb
rm -f protonvpn.deb
sudo apt update

# 4. Instalar o Cliente CLI do ProtonVPN
echo "[4/9] Instalando cliente CLI do ProtonVPN..."
sudo apt install -y protonvpn-cli

# 5. Fazer login
echo "[5/9] Faça login no ProtonVPN (interface interativa)..."
if [ -z "$PROTONVPN_USER" ]; then
  echo "Por favor, digite seu nome de usuário do ProtonVPN:"
  read -r PROTONVPN_USER
fi
protonvpn-cli login "$PROTONVPN_USER"

# 6. Verificar Status
echo "[6/9] Verificando status do ProtonVPN..."
protonvpn-cli status

# 7. Conectar ao ProtonVPN (por padrão, país: US)
echo "[7/9] Conectando ao servidor dos Estados Unidos (US)..."
protonvpn-cli c --cc US

# 8. Verificar Conexão
echo "[8/9] Verificando status da conexão VPN..."
protonvpn-cli status

# 9. Instrução para desconectar
echo "[9/9] Para desconectar, use: protonvpn-cli d"
echo "Para reconectar rapidamente: protonvpn-cli r"
echo "Para visualizar logs: protonvpn-cli --get-logs"

echo "==============================================="
echo "     ProtonVPN instalado e configurado!"
echo "==============================================="
