import os
import subprocess
import requests
import shutil
import time
from datetime import datetime

################################################
############ VERIFICAR Y CAMBIAR ###############
################################################

# URL del binario
binary_url = "https://github.com/nymtech/nym/releases/latest/download/nym-node"  # Se puede cambiar por la version especifica que se quiere actualizar, por default es latest
binary_path = "/usr/local/bin/nym-node"  # Ruta donde debe estar instalado el binario
service_name = "nym-node.service"  # Nombre del servicio systemd

################################################

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
    config_path = "/.nym/nym-nodes/"
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
    
    # Verificar si el binario actual existe y obtener su versión
    current_version = get_binary_version(binary_path)
    
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
