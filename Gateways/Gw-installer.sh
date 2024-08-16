#!/bin/bash

####
#   SCRIPT EN PERIODO DE PRUEBAS, USELO BAJO SU PROPIA RESPONSABILIDAD
####

# Definir el directorio de trabajo y variables para inicializar el nodo
# PATH Directorio para instalar el binario
# ID Nombre asociado al nodo
# YOUR_DOMAIN es el Hostname asociado al nodo. ej. GW1.nymtech.net
# COUNTRY  Nombre del pais donde esta el VPS, conviene ponerlo en alpha2 ej. AR para Argentina, ES para España (google it)
path=~/Nymnode
ID="<ID>"
YOUR_DOMAIN="<YOUR_DOMAIN>"
COUNTRY="<COUNTRY_FULL_NAME>"

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
# Función para obtener la IPv4, IPv6 y el gateway de IPv6
get_network_info() {
    echo "Obteniendo la información de red..."

    # Obtener la dirección IPv4
    IPv4=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1)
    echo "Dirección IPv4: $IPv4"

    # Obtener la dirección IPv6
    IPv6=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1)
    echo "Dirección IPv6: $IPv6"

    # Obtener el gateway de IPv6
    IPv6_Gateway=$(ip -6 route show default | grep default | awk '{print $3}')
    echo "Gateway IPv6: $IPv6_Gateway"

    # Las variables ahora contienen las direcciones IPv4, IPv6 y el gateway de IPv6
}

# Función para limpiar configuraciones antiguas
clean_old_configurations() {
    local config_dir="$HOME/.nym/nym-nodes/"

    if [ -d "$config_dir" ]; then
        echo "Eliminando archivos y directorios en $config_dir"
        if rm -rf "$config_dir"; then
            echo "Archivos y directorios eliminados correctamente."
        else
            echo "Error al eliminar archivos en $config_dir."
        fi
    else
        echo "El directorio $config_dir no existe."
    fi
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
    mkdir -p "$path"
    cd "$path" || exit

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

# Función para inicializar el nodo
initialize_node() {
    echo "Inicializando el nodo con las siguientes opciones:"
    echo "ID: $ID"
    echo "Dominio: $YOUR_DOMAIN"
    echo "País: $COUNTRY"

    # Comando para inicializar el nodo sin ejecutarlo
    "$path/nym-node" run --id "$ID" --init-only --mode exit-gateway \
        --public-ips "$(curl -4 https://ifconfig.me)" \
        --hostname "$YOUR_DOMAIN" \
        --http-bind-address 0.0.0.0:8080 \
        --mixnet-bind-address 0.0.0.0:1789 \
        --location "$COUNTRY" \
        --accept-operator-terms-and-conditions \
        --wireguard-enabled true
}

# Función para agregar una dirección IPv6 al archivo config.toml sin duplicar IPs existentes
add_ipv6_to_config() {
    local nombre_id="$1"
    local ipv4="$2"
    local ipv6="$3"
    local config_path="$HOME/.nym/nym-nodes/$nombre_id/config/config.toml"

    if [ -f "$config_path" ]; then
        # Leer el contenido del archivo
        mapfile -t lines < "$config_path"

        local public_ips_block=()
        local in_public_ips_block=false
        local block_modified=false
        local new_lines=()

        for line in "${lines[@]}"; do
            if [[ $line == *"public_ips ="* ]]; then
                in_public_ips_block=true
                public_ips_block+=("$line")
            elif $in_public_ips_block; then
                public_ips_block+=("$line")
                if [[ $line == *"]"* ]]; then
                    in_public_ips_block=false

                    # Extraer las IPs existentes
                    local existing_ips
                    existing_ips=$(echo "${public_ips_block[*]}" | grep -oP "'\K[^']+")

                    # Añadir la nueva IPv6 si no está ya presente
                    local new_ips=("$ipv4")
                    for ip in "${existing_ips[@]}"; do
                        if [[ -n "$ip" && "$ip" != "$ipv4" && "$ip" != "$ipv6" ]]; then
                            new_ips+=("$ip")
                        fi
                    done
                    if [[ ! " ${new_ips[*]} " =~ " $ipv6 " ]]; then
                        new_ips+=("$ipv6")
                    fi

                    # Reconstruir el bloque public_ips
                    public_ips_block=("public_ips = [")
                    for ip in "${new_ips[@]}"; do
                        public_ips_block+=("'$ip',")
                    done
                    public_ips_block+=("]")

                    # Marcar que el bloque fue modificado
                    block_modified=true
                fi
            fi

            # Agregar líneas al nuevo contenido del archivo
            if $block_modified; then
                new_lines+=("${public_ips_block[@]}")
                block_modified=false
            else
                new_lines+=("$line")
            fi
        done

        # Si no se encontró el bloque public_ips, agregarlo
        if [[ ! " ${new_lines[*]} " =~ "public_ips =" ]]; then
            new_lines+=("public_ips = [")
            new_lines+=("'$ipv4',")
            new_lines+=("'$ipv6'")
            new_lines+=("]")
        fi

        # Escribir el nuevo contenido en el archivo
        printf "%s\n" "${new_lines[@]}" > "$config_path"
        echo "Dirección IPv6 añadida correctamente en $config_path"
    else
        echo "El archivo $config_path no existe. Asegúrate de que nym-node haya sido inicializado correctamente."
    fi
}

# Función para crear un servicio systemd para nym-node
create_systemd_service() {
    local nombre_id="$ID"
    local service_file="/etc/systemd/system/nym-node.service"
    local exec_start_cmd="$path/nym-node run --id $nombre_id --deny-init --wireguard-enabled true --mode exit-gateway --accept-operator-terms-and-conditions"

    local service_content="[Unit]
Description=Nym Node
StartLimitInterval=350
StartLimitBurst=10

[Service]
User=root
LimitNOFILE=65536
ExecStart=$exec_start_cmd
KillSignal=SIGINT
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
"

    # Crear el archivo de servicio
    echo "$service_content" | sudo tee "$service_file" > /dev/null

    # Recargar los servicios systemd, habilitar y empezar el servicio
    sudo systemctl daemon-reload
    sudo systemctl enable nym-node.service
    sudo systemctl start nym-node.service

    if [ $? -eq 0 ]; then
        echo "Servicio systemd creado y activado en $service_file"
    else
        echo "Error al crear o iniciar el servicio systemd."
    fi
}
# Función para actualizar las interfaces de red con rutas IPv6
update_network_interfaces() {
    local ipv6_gateway="$IPV6_GATEWAY"
    local interfaces_path="/etc/network/interfaces"

    # Comprobar si el archivo /etc/network/interfaces existe
    if [ -f "$interfaces_path" ]; then
        # Definir las rutas a agregar
        local post_up_route_1="post-up /sbin/ip -r route add $ipv6_gateway dev eth0"
        local post_up_route_2="post-up /sbin/ip -r route add default via $ipv6_gateway"

        # Comprobar si las rutas ya existen en el archivo
        if ! grep -qF "$post_up_route_1" "$interfaces_path"; then
            echo "$post_up_route_1" | sudo tee -a "$interfaces_path" > /dev/null
            echo "Añadida ruta: $post_up_route_1"
        else
            echo "La ruta $post_up_route_1 ya existe."
        fi

        if ! grep -qF "$post_up_route_2" "$interfaces_path"; then
            echo "$post_up_route_2" | sudo tee -a "$interfaces_path" > /dev/null
            echo "Añadida ruta: $post_up_route_2"
        else
            echo "La ruta $post_up_route_2 ya existe."
        fi
    else
        echo "El archivo $interfaces_path no existe. Verifica la configuración de red."
    fi
}
# Función para generar un nombre de sesión aleatorio
generate_random_session_name() {
    local length=${1:-8}
    local letters="abcdefghijklmnopqrstuvwxyz"
    local session_name=""
    for (( i=0; i<length; i++ )); do
        session_name+="${letters:RANDOM%${#letters}:1}"
    done
    echo "$session_name"
}
# Función para configurar una sesión de tmux
setup_tmux_session() {
    local nombre_id="$ID"
    local session_name=$(generate_random_session_name)

    # Comandos a ejecutar en cada panel
    local comandos=(
        'journalctl -u nym-node -f'  # Comando para el panel superior izquierdo
        'watch ip addr show nymtun0'  # Comando para el panel inferior izquierdo
        "$path/nym-node bonding-information --id $nombre_id"  # Comando para el panel inferior derecho
    )

    # Crear una nueva sesión en tmux
    tmux new-session -d -s "$session_name"

    # Dividir la ventana en dos paneles horizontalmente
    tmux split-window -v -t "$session_name"

    # Dividir el panel inferior en dos paneles verticalmente
    tmux split-window -h -t "${session_name}:0.1"

    # Enviar comandos a cada panel
    tmux send-keys -t "${session_name}:0.0" "${comandos[0]}" C-m
    tmux send-keys -t "${session_name}:0.1" "${comandos[1]}" C-m
    tmux send-keys -t "${session_name}:0.2" "${comandos[2]}" C-m

    # Adjuntar a la sesión para ver los resultados
    tmux attach -t "$session_name"
}


# Función principal que llama a todas las demás funciones
#Por dudas leer los comentarios de cada funcion
main() {
    update_system
    install_dependencies
    install_ufw
    install_rust
    configure_ufw
    get_network_info
    change_ip_priority
    configure_nofile_limit
    clean_old_configurations
    update_network_interfaces
    install_nym_node
    initialize_node
    add_ipv6_to_config "$ID" "$IPV4" "$IPV6"
    create_systemd_service
    setup_tmux_session
    
}

# Ejecución del script principal
main
