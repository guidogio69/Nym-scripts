#!/bin/bash

# Verificación de permisos de root o sudo
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root o utilizando sudo."
  exit 1
fi

# Función para actualizar el sistema
update_system() {
    echo "Actualizando el sistema..."
    apt update -y && apt --fix-broken install -y
}

# Función para instalar dependencias
install_dependencies() {
    echo "Instalando dependencias..."
    # Verificar si los paquetes ya están instalados
    dependencies=(ca-certificates jq curl wget ufw tmux pkg-config build-essential libssl-dev git)
    for package in "${dependencies[@]}"; do
        if dpkg -l | grep -q "^ii  $package"; then
            echo "$package ya está instalado."
        else
            apt -y install "$package"
        fi
    done
}

# Función para asegurar la instalación de ufw
install_ufw() {
    echo "Verificando instalación de UFW..."
    if ! dpkg -l | grep -q "^ii  ufw"; then
        apt install ufw --fix-missing
    else
        echo "UFW ya está instalado."
    fi
}

# Función para instalar RUSTC
install_rust() {
    echo "Instalando Rust..."
    if ! command -v rustc &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    else
        echo "Rust ya está instalado."
    fi
}

# Función para configurar ufw con los puertos específicos
configure_ufw() {
    echo "Configurando UFW con puertos específicos..."

    declare -A ports=(
        [80/tcp]=HTTP
        [443/tcp]=HTTPS
        [1789/tcp]=Nym
        [1790/tcp]=Nym
        [8080/tcp]=Nym
        [9000/tcp]=Nym
        [9001/tcp]=Nym
        [51822/udp]=WireGuard
    )

    for port in "${!ports[@]}"; do
        if ! ufw status | grep -q "$port"; then
            ufw allow "$port"
            echo "Puerto $port (${ports[$port]}) permitido."
        else
            echo "Puerto $port (${ports[$port]}) ya está permitido."
        fi
    done
}

# Función para cambiar la prioridad de IPv4 sobre IPv6
change_ip_priority() {
    echo "Cambiando prioridad de IPv4 sobre IPv6..."
    if grep -q '^precedence ::ffff:0:0/96 100' /etc/gai.conf; then
        echo "La prioridad de IPv4 sobre IPv6 ya está configurada."
    else
        sed -i 's/^#precedence ::ffff:0:0\/96 10/precedence ::ffff:0:0\/96 100/' /etc/gai.conf
        systemctl restart systemd-networkd
        echo "Prioridad de IPv4 sobre IPv6 configurada."
    fi
}

# Función para configurar el límite de archivos abiertos
configure_nofile_limit() {
    echo "Configurando límite de archivos abiertos..."
    if grep -q "^DefaultLimitNOFILE=65535" /etc/systemd/system.conf; then
        echo "El límite de archivos abiertos ya está configurado."
    else
        echo "DefaultLimitNOFILE=65535" >> /etc/systemd/system.conf
        echo "Límite de archivos abiertos configurado."
    fi
}

# Función para descargar e instalar nym-node y network_tunnel_manager.sh
install_nym_node() {
    echo "Instalando nym-node y network_tunnel_manager.sh..."
    mkdir -p /root/Nymnode
    cd /root/Nymnode || exit

    # Verificar si nym-node ya está descargado
    if [ -f "nym-node" ]; then
        echo "nym-node ya está descargado."
    else
        curl -o nym-node -L https://github.com/nymtech/nym/releases/latest/download/nym-node && chmod +x nym-node
        echo "nym-node descargado e instalado."
    fi

    # Verificar si network_tunnel_manager.sh ya está descargado
    if [ -f "network_tunnel_manager.sh" ]; then
        echo "network_tunnel_manager.sh ya está descargado."
    else
        curl -o network_tunnel_manager.sh -L https://gist.githubusercontent.com/tommyv1987/ccf6ca00ffb3d7e13192edda61bb2a77/raw/3c0a38c1416f8fdf22906c013299dd08d1497183/network_tunnel_manager.sh && chmod +x network_tunnel_manager.sh
        echo "network_tunnel_manager.sh descargado e instalado."
    fi
}

# Función principal que llama a todas las demás funciones
main() {
    update_system
    install_dependencies
    install_ufw
    install_rust
    configure_ufw
    change_ip_priority
    configure_nofile_limit
    install_nym_node
}

# Ejecución del script principal
main
