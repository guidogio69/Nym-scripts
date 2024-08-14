import os
import subprocess
import requests
import shutil
import time
from datetime import datetime
from packaging import version

################################################
############ VERIFICAR Y CAMBIAR ###############
################################################

# URL del binario
binary_url = "https://github.com/nymtech/nym/releases/latest/download/nym-node"  # Se puede cambiar por la version especifica que se quiere actualizar, por default es latest
binary_path = "/usr/local/bin/nym-node"  # Ruta donde debe estar instalado el binario
service_name = "nym-node.service"  # Nombre del servicio systemd

################################################
def extract_node_id(service_file="/etc/systemd/system/nym-node.service"):
    """
    Extrae el ID del nodo desde el archivo de servicio systemd y lo establece como una variable de entorno.
    
    :param service_file: Ruta al archivo de servicio systemd.
    :return: El ID del nodo si se encuentra, de lo contrario None.
    """
    try:
        with open(service_file, "r") as file:
            lines = file.readlines()

        node_id = None

        for line in lines:
            if line.startswith("ExecStart"):
                # Buscar la opción --id
                parts = line.split()
                for i, part in enumerate(parts):
                    if part == "--id" and i + 1 < len(parts):
                        node_id = parts[i + 1]
                        break

        if node_id:
            # Establecer la variable de entorno con el ID del nodo
            os.environ["NYM_NODE_ID"] = node_id
            print(f"Variable de entorno NYM_NODE_ID establecida en: {node_id}")
            return node_id
        else:
            print("No se encontró el ID del nodo en el archivo de servicio.")
            return None

    except FileNotFoundError:
        print(f"El archivo de servicio {service_file} no existe.")
        return None
    except Exception as e:
        print(f"Error al leer el archivo de servicio: {e}")
        return None

def set_env_variable():
    """Establecer una variable de entorno con la ruta del binario."""
    os.environ["NYM_BINARY_PATH"] = binary_path
    print(f"Variable de entorno NYM_BINARY_PATH establecida en: {binary_path}")

def get_binary_version(binary_path):
    """Obtener la versión del binario utilizando el comando `build-info`."""
    try:
        version_output = subprocess.check_output([binary_path, "build-info"], text=True)
        for line in version_output.splitlines():
            if "Build Version" in line:
                version = line.split()[-1].strip()
                print(f"Versión actual del binario: {version}")
                return version
        print("No se encontró la versión en la salida del comando.")
        return None
    except subprocess.CalledProcessError as e:
        print(f"No se pudo obtener la versión del binario: {e}")
        return None
    except FileNotFoundError:
        print(f"El binario no existe en la ruta {binary_path}.")
        return None
    
def update_config_toml(config_file_path):
    """
    Actualiza el archivo config.toml cambiando 'enabled = false' a 'enabled = true' en la sección [wireguard].
    
    :param config_file_path: Ruta al archivo config.toml.
    """
    try:
        # Leer el archivo
        with open(config_file_path, "r") as file:
            lines = file.readlines()
        
        updated_lines = []
        in_wireguard_section = False
        
        for line in lines:
            if line.strip().startswith("[wireguard]"):
                in_wireguard_section = True
            elif line.strip().startswith("[") and in_wireguard_section:
                in_wireguard_section = False
            
            if in_wireguard_section and line.strip().startswith("enabled"):
                if "enabled = false" in line:
                    line = line.replace("enabled = false", "enabled = true")
                    print("Cambiado 'enabled = false' a 'enabled = true'.")
            
            updated_lines.append(line)
        
        # Guardar los cambios
        with open(config_file_path, "w") as file:
            file.writelines(updated_lines)
        
        print(f"Archivo de configuración actualizado: {config_file_path}")
    
    except FileNotFoundError:
        print(f"El archivo de configuración {config_file_path} no existe.")
    except Exception as e:
        print(f"Error al actualizar el archivo de configuración: {e}")

def is_version_eligible(current_version, minimum_version="1.1.5"):
    """
    Comprueba si la versión actual del binario es mayor o igual a la versión mínima requerida.
    
    :param current_version: La versión actual del binario.
    :param minimum_version: La versión mínima requerida.
    :return: True si la versión actual es mayor o igual a la mínima, False en caso contrario.
    """
    return version.parse(current_version) >= version.parse(minimum_version)

def check_and_update_wireguard(service_file=f"/etc/systemd/system/{service_name}"):
    """
    Verifica y actualiza la opción '--wireguard-enabled true' en el archivo de servicio systemd.
    
    :param service_file: Ruta al archivo de servicio systemd.
    """
    try:
        with open(service_file, "r") as file:
            lines = file.readlines()
        
        updated_lines = []
        option_found = False
        execstart_found = False
        
        for line in lines:
            if line.startswith("ExecStart"):
                execstart_found = True
                if "--wireguard-enabled" in line:
                    if "--wireguard-enabled false" in line:
                        # Cambiar false a true
                        line = line.replace("--wireguard-enabled false", "--wireguard-enabled true")
                        print(f"Cambiando '--wireguard-enabled false' a '--wireguard-enabled true'.")
                    option_found = True
                else:
                    # Si no existe la opción, agregarla
                    line = line.rstrip() + " --wireguard-enabled true\n"
                    print(f"Agregando '--wireguard-enabled true' a la línea de ExecStart.")
            updated_lines.append(line)
        
        if not execstart_found:
            print(f"No se encontró la línea 'ExecStart' en {service_file}.")
        elif not option_found:
            print(f"Agregada la opción '--wireguard-enabled true' a la línea 'ExecStart'.")
        
        # Guardar los cambios si se realizaron modificaciones
        with open(service_file, "w") as file:
            file.writelines(updated_lines)
        
        # Recargar la configuración del servicio systemd
        subprocess.run(["sudo", "systemctl", "daemon-reload"], check=True)
        print("Recargada la configuración de systemd.")
    
    except FileNotFoundError:
        print(f"El archivo de servicio {service_file} no existe.")
    except Exception as e:
        print(f"Error al modificar el archivo de servicio: {e}")


def download_latest_binary(url, download_path):
    """Descargar el binario desde la URL especificada."""
    response = requests.get(url, stream=True)
    response.raise_for_status()
    with open(download_path, 'wb') as f:
        shutil.copyfileobj(response.raw, f)
    os.chmod(download_path, 0o755)  # Asegurar que el binario es ejecutable
    print(f"Descargado nuevo binario a {download_path}")

def stop_service(service):
    """Detener el servicio systemd."""
    subprocess.run(["sudo", "systemctl", "stop", service], check=True)
    print(f"Servicio {service} detenido")

def start_service(service):
    """Iniciar el servicio systemd."""
    subprocess.run(["sudo", "systemctl", "start", service], check=True)
    print(f"Servicio {service} iniciado")

def replace_binary(new_binary, current_binary):
    """Reemplazar el binario actual con el nuevo."""
    shutil.move(new_binary, current_binary)
    print(f"Reemplazado el binario en {current_binary}")

def backup_config():
    """Crear un backup de los archivos de configuración y recomendar su transferencia por SCP."""
    config_path = os.path.expanduser("~/.nym/nym-nodes/")
    home_dir = os.path.expanduser("~")
    backup_dir = os.path.join(home_dir, "nym_backup")
    
    # Asegurarse de que el directorio de backup existe
    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir)
    
    # Nombre del archivo de backup con timestamp
    backup_file = os.path.join(backup_dir, f"nym-nodes-backup-{datetime.now().strftime('%Y%m%d%H%M%S')}.tar.gz")
    
    # Crear el archivo tar.gz de backup
    subprocess.run(["tar", "-czf", backup_file, config_path], check=True)
    print(f"Backup creado exitosamente en {backup_file}")
    
    # Recomendación para extraer el archivo y enviarlo por SCP
    print(f"Recomendación: Extrae el archivo de backup y envíalo por SCP a otro sitio:\nscp {backup_file} user@remote_host:/path/to/destination")

def main():
    # Establecer la variable de entorno
    set_env_variable()

    # Crear un backup de los archivos de configuración
    backup_config()

    # Extraer el ID del nodo y establecerlo como una variable de entorno
    node_id = extract_node_id()
   
    # Verificar si el binario actual existe y obtener su versión
    current_version = get_binary_version(binary_path)
    
    if current_version and is_version_eligible(current_version):
            print(f"La versión {current_version} es elegible para actualización.")
            
            if node_id:
                # Ruta al archivo config.toml
                config_path = os.path.expanduser(f"~/.nym/nym-nodes/{node_id}/config")

                # Actualizar el archivo config.toml
                update_config_toml(config_path)

                # Verificar y actualizar la opción wireguard en el servicio systemd
                check_and_update_wireguard()
            else:
                print(f"La versión {current_version} no es elegible para la actualización. Se omiten los cambios de Wireguard.")


    # Descarga el nuevo binario a un archivo temporal
    tmp_binary_path = "/tmp/nym-node-new"
    download_latest_binary(binary_url, tmp_binary_path)
    
    # Obtiene la versión del nuevo binario
    new_version = get_binary_version(tmp_binary_path)
    
    if not current_version:
        # Si el binario no existe, lo movemos directamente
        print(f"El binario no existe en {binary_path}. Instalando nueva versión {new_version}...")
        replace_binary(tmp_binary_path, binary_path)
    else:
        # Comparación de versiones
        if new_version and new_version > current_version:
            print(f"Nueva versión {new_version} es mayor que la versión actual {current_version}. Actualizando...")
            
            # Detiene el servicio antes de reemplazar el binario
            stop_service(service_name)
            
            # Inicia el contador de tiempo
            start_time = time.time()
            
            # Reemplaza el binario existente con el nuevo
            replace_binary(tmp_binary_path, binary_path)
            
            # Reinicia el servicio con el nuevo binario
            start_service(service_name)
            
            # Calcula el tiempo de caída del servicio
            downtime = time.time() - start_time
            print(f"El servicio estuvo caído durante {downtime:.2f} segundos")
            
            print("Actualización completada exitosamente")
            print("####################################")
            print("RECUERDA REALIZAR LOS CAMBIOS NECESARIOS EN LA WALLET")
            print("####################################")
        else:
            print(f"La versión instalada ({current_version}) ya es la más reciente. No se realizará la actualización.")
            os.remove(tmp_binary_path)  # Elimina el binario descargado si no es necesario

if __name__ == "__main__":
    main()
