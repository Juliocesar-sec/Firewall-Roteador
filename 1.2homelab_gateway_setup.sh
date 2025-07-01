#!/bin/bash

# ⚙️ Configuração básica
LAN_IFACE="eth0"
WAN_IFACE="eth1"
LAN_SUBNET="192.168.1.0/24"
SQUID_PORT="3128"
SQUID_HOSTNAME="meu_homelab_firewall"

# 🛠️ Atualizações e pacotes essenciais
echo "[1/6] Atualizando sistema e instalando pacotes..."
apt update && apt upgrade -y
apt install -y squid ufw iptables-persistent

# 🔄 Habilitar IP Forwarding
echo "[2/6] Habilitando IP Forwarding..."
sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# 🐙 Configurar Squid como proxy transparente
echo "[3/6] Configurando Squid..."
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
cat > /etc/squid/squid.conf <<EOF
http_port $SQUID_PORT transparent
acl localnet src $LAN_SUBNET
http_access allow localnet
http_access deny all
cache_dir ufs /var/spool/squid 100 16 256
visible_hostname $SQUID_HOSTNAME
EOF
systemctl restart squid
systemctl enable squid

# 🔥 Configurar UFW e permitir SSH
echo "[4/6] Configurando firewall com UFW..."
ufw allow ssh
ufw --force enable

# 🧱 Regras NAT e redirecionamento para o Squid via UFW
echo "[5/6] Adicionando regras NAT e proxy no UFW..."
UFW_RULES="/etc/ufw/before.rules"
cp "$UFW_RULES" "$UFW_RULES.bak"

awk -v wan="$WAN_IFACE" -v lan="$LAN_IFACE" -v port="$SQUID_PORT" '
BEGIN { nat_done = 0 }
/\*nat/ {
    print
    print "# NAT e proxy transparente"
    print "-A POSTROUTING -o " wan " -j MASQUERADE"
    print "-A PREROUTING -i " lan " -p tcp --dport 80 -j REDIRECT --to-port " port
    nat_done = 1
    next
}
/^COMMIT/ && nat_done == 1 {
    print
    nat_done = 2
    next
}
{ print }
END {
    if (nat_done < 2) print "COMMIT"
}' "$UFW_RULES.bak" > "$UFW_RULES"

ufw disable
ufw --force enable

# ✅ Status final
echo "[6/6] Verificação da configuração..."
systemctl status squid | grep Active
echo "Verifique o log do Squid com: tail -f /var/log/squid/access.log"
echo "Dispositivos conectados à $LAN_IFACE devem navegar via proxy transparente."
