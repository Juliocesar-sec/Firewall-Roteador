#!/bin/bash

# Instalação e Configuração do Suricata no Debian 12 (Bookworm)
# Autor: Seu Nome
# Versão: 1.0

# Variáveis
REDE_MONITORADA="192.168.1.1/24"
INTERFACE="eth0"  # Substitua conforme necessário

echo "===================================="
echo "   Instalação do Suricata - Debian 12"
echo "===================================="

# 1. Atualizar sistema
echo "[1/10] Atualizando sistema..."
sudo apt update && sudo apt upgrade -y

# 2. Instalar Suricata
echo "[2/10] Instalando Suricata..."
sudo apt install -y suricata

# 3. Verificar versão do Suricata
echo "[3/10] Verificando instalação do Suricata..."
suricata --version || { echo "Erro: Suricata não instalado corretamente."; exit 1; }

# 4. Configurar Suricata
echo "[4/10] Configurando Suricata..."

CONFIG_FILE="/etc/suricata/suricata.yaml"

# Backup do arquivo original
sudo cp $CONFIG_FILE ${CONFIG_FILE}.bak

# 4.1 - Alterar HOME_NET
echo "[4.1] Configurando HOME_NET..."
sudo sed -i "s|HOME_NET:.*|HOME_NET: [${REDE_MONITORADA}]|g" $CONFIG_FILE

# 4.2 - Configurar interface de rede
echo "[4.2] Configurando interface para captura: $INTERFACE..."
if ! grep -q "interface: $INTERFACE" $CONFIG_FILE; then
  sudo sed -i "/^ *- interface:/c\  - interface: $INTERFACE" $CONFIG_FILE
fi

# 4.3 - Habilitar modo IPS (simulado como comentário: Suricata não tem opção 'IPS: yes')
echo "[4.3] *Nota: Suricata opera como IPS se integrado com NFQUEUE ou similar.*"

# 5. Testar configuração
echo "[5/10] Testando configuração do Suricata..."
sudo suricata -T -c $CONFIG_FILE -v || { echo "Erro: Teste de configuração falhou."; exit 1; }

# 6. Iniciar e habilitar o serviço
echo "[6/10] Iniciando e habilitando Suricata..."
sudo systemctl start suricata
sudo systemctl enable suricata

# 7. Logs e Monitoramento
echo "[7/10] Verificando logs..."
echo "Logs disponíveis:"
echo "  - /var/log/suricata/suricata.log"
echo "  - /var/log/suricata/eve.json"
echo "Use: sudo tail -f /var/log/suricata/eve.json"

# 8. Atualização de regras
echo "[8/10] Instalando e atualizando regras com suricata-update..."
sudo apt install -y suricata-update
sudo suricata-update

# 9. Finalização
echo "[9/10] Suricata instalado e configurado com sucesso!"
echo "Rede monitorada: $REDE_MONITORADA"
echo "Interface usada: $INTERFACE"

# 10. Referências
echo "[10/10] Documentação:"
echo " - https://docs.suricata.io"
echo " - https://suricata.io"
