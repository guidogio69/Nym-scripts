[USO]

Descarga el fichero y asignale permisos de ejecucion, Recomendable hacer todo el proceso como ROOT y trabajar sobre el directorio /root
    cd / &&  curl -o Gw-installer.sh -L https://raw.githubusercontent.com/guidogio69/Nym-scripts/main/Gateways/Gw-installer.sh && chmod +x Gw-installer.sh

Edita el archivo
    vim Gw-installer.sh

Modifica las variables solicitadas
ID Nombre asociado al nodo
YOUR_DOMAIN es el Hostname asociado al nodo. ej. GW1.nymtech.net
COUNTRY  Nombre del pais donde esta el VPS, conviene ponerlo en alpha2 ej. AR para Argentina, ES para España (google it)

ID="<ID>"
YOUR_DOMAIN="<YOUR_DOMAIN>"
COUNTRY="<COUNTRY_FULL_NAME>"

Guarda la configuracion y ejecuta el archivo
./Gw-installer.sh

Si todo finaliza OK, se abrirá una interfaz de tmux donde tendras el log corriendo, y los datos para hacer el bonding.


[USAGE]
Download the file and assign execution permissions, it is recommended to do the whole process as ROOT and work on the /root directory.
    cd / &&  curl -o Gw-installer.sh -L https://raw.githubusercontent.com/guidogio69/Nym-scripts/main/Gateways/Gw-installer.sh && chmod +x Gw-installer.sh

Edit the file
    vim Gw-installer.sh

Modify the requested variables
ID Name associated to the node
YOUR_DOMAIN is the Hostname associated to the node. e.g. GW1.nymtech.net
COUNTRY Name of the country where the VPS is located, you should put it in alpha2 e.g. AR for Argentina, ES for Spain (google it)

ID="<ID>"
YOUR_DOMAIN="<YOUR_DOMAIN>"
COUNTRY="<COUNTRY_FULL_NAME>"

Save the configuration and run the file
./Gw-installer.sh

If everything finishes OK, it will open a tmux interface where you will have the log running, and the data to do the bonding.



[EN]
We are NYM Spain Operator [NSO Squad].
We will continue to grow and learn. We will keep fighting for privacy and anonymity on the internet, as a fundamental right of the Knowledge Society.

[ES]
Somos NYM Spain Operator [NSO Squad].
Seguiremos creciendo y aprendiendo. Seguiremos luchando por la privacidad y el anonimato en internet, como derecho fundamental de la Sociedad del Conocimiento.

# Nym-scripts
[EN]
We create scripts to be able to test our nodes, both upddate and assembly.

[ES]
Creamos scripts para poder hacer pruebas en nuestros nodos, tantos de upddate, como montaje

