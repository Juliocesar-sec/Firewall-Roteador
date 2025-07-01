#!/bin/bash

# ==============================================================================
# Script Melhorado de Configuração de Gateway no Kali Linux
# Com IP forwarding persistente, DHCP, UFW com NAT automático e Suricata
# Interfaces:
#   eth1 - modem 4G (DHCP)
#   eth0 - GL.iNet WAN (IP estático 192.168.10.1)
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

echo "Iniciando configuração do Gateway no Kali Linux..."
echo "-------------------------------------------------"

# --- 1. IP Forwarding Persistente ---
echo "[PASSO 1/6] Ativando IP forwarding (persistente)..."
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.d/99-ip-forward.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-ip-forward.conf >/dev/null
fi
sudo sysctl --system >/dev/null
ip_forward_status=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ "$ip_forward_status" == "1" ]]; then
    echo "IP forwarding ativado."
else
    echo "ERRO: IP forwarding não ativado!"
    exit 1
fi

# --- 2. Configurar IP estático em eth0 ---
echo "[PASSO 2/6] Configurando IP estático 192.168.10.1 para eth0..."

# Limpa configurações antigas de eth0 no /etc/network/interfaces
sudo sed -i '/^auto eth0$/,/^iface eth0 inet/d' /etc/network/interfaces

# Adiciona configuração estática nova
sudo tee -a /etc/network/interfaces >/dev/null <<EOF

# Configuração estática para eth0 (GL.iNet WAN)
auto eth0
iface eth0 inet static
    address 192.168.10.1
    netmask 255.255.255.0
EOF

echo "Reiniciando interface eth0..."
sudo ip addr flush dev eth0
if sudo ifdown eth0 2>/dev/null; then
    echo "Interface eth0 desativada."
fi
sudo ifup eth0

sleep 3
ip_eth0=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)
if [[ "$ip_eth0" == "192.168.10.1" ]]; then
    echo "eth0 configurada com sucesso: $ip_eth0"
else
    echo "AVISO: eth0 não tem o IP esperado. IP atual: ${ip_eth0:-nenhum}"
    echo "Pode ser necessário reiniciar o sistema."
fi

# --- 3. Instalar e configurar ISC DHCP Server ---
echo "[PASSO 3/6] Instalando e configurando ISC DHCP Server..."
sudo apt update -qq
sudo apt install -y isc-dhcp-server

# Configura interface para DHCP server
echo 'INTERFACESv4="eth0"' | sudo tee /etc/default/isc-dhcp-server >/dev/null

# Backup do arquivo de configuração original
if [ ! -f /etc/dhcp/dhcpd.conf.bak ]; then
    sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
fi

# Configuração do DHCP para a rede 192.168.10.0/24
sudo tee /etc/dhcp/dhcpd.conf >/dev/null <<EOF
# dhcpd.conf customizado

allow unknown-clients;
ddns-update-style none;

subnet 192.168.10.0 netmask 255.255.255.0 {
    range 192.168.10.100 192.168.10.150;
    option routers 192.168.10.1;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
    option broadcast-address 192.168.10.255;
    default-lease-time 600;
    max-lease-time 7200;
}
EOF

# Reinicia e habilita DHCP
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server

if sudo systemctl is-active --quiet isc-dhcp-server; then
    echo "ISC DHCP Server iniciado com sucesso."
else
    echo "ERRO: Falha ao iniciar ISC DHCP Server. Verifique logs com: sudo journalctl -u isc-dhcp-server"
    exit 1
fi

# --- 4. Configurar UFW com regras básicas + NAT automático ---
echo "[PASSO 4/6] Configurando UFW e regras NAT..."

echo "Resetando UFW..."
sudo ufw --force reset

echo "Definindo políticas padrão: negar tudo."
sudo ufw default deny incoming
sudo ufw default deny outgoing
sudo ufw default deny routed

echo "Permitindo DHCP (UDP 67/68) na eth0..."
sudo ufw allow in on eth0 to any port 67 proto udp
sudo ufw allow out on eth0 to any port 68 proto udp

echo "Permitindo tráfego de saída pela eth1 (internet)..."
sudo ufw allow out on eth1

echo "Permitindo encaminhamento entre eth0 e eth1..."
sudo ufw route allow in on eth1 out on eth0
sudo ufw route allow in on eth0 out on eth1

# Adiciona bloco NAT automático no before.rules se ainda não existir
BEFORE_RULES="/etc/ufw/before.rules"
if ! sudo grep -q "START CUSTOM NAT RULES" "$BEFORE_RULES"; then
    echo "Inserindo regras NAT no $BEFORE_RULES..."
    sudo sed -i '1i# START CUSTOM NAT RULES\n*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -o eth1 -j MASQUERADE\nCOMMIT\n# END CUSTOM NAT RULES\n' "$BEFORE_RULES"
else
    echo "Regras NAT já presentes no $BEFORE_RULES."
fi

echo "Habilitando UFW..."
sudo ufw enable

if sudo ufw status | grep -q "Status: active"; then
    echo "UFW ativado com sucesso."
else
    echo "ERRO: Falha ao ativar UFW."
    exit 1
fi

# --- 5. Instalar e configurar Suricata ---
echo "[PASSO 5/6] Instalando Suricata IDS/IPS..."
sudo apt install -y suricata

echo "Atualizando regras do Suricata..."
sudo suricata-update >/dev/null

sudo systemctl enable suricata
sudo systemctl restart suricata

if sudo systemctl is-active --quiet suricata; then
    echo "Suricata iniciado com sucesso."
else
    echo "ERRO: Falha ao iniciar Suricata. Verifique logs com: sudo journalctl -u suricata"
    exit 1
fi

echo "[PASSO 6/6] Configuração finalizada."

echo "
IMPORTANTE:
- Verifique as variáveis HOME_NET e interfaces em /etc/suricata/suricata.yaml.
- Reinicie o roteador GL.iNet para garantir DHCP e rede corretos.
- Para monitorar logs do Suricata: sudo tail -f /var/log/suricata/eve.json
- Para ver status do firewall: sudo ufw status verbose
"

echo "Configuração concluída com sucesso!"
