#!/bin/bash
###############################################################################
##                                                                           ##
## Auteur : José GIL                                                         ##
##                                                                           ## 
## Synopsis : Script d’installation et de configuration automatique d'un     ##
##            serveur LAMP (Apache, MariaDB, PHP et phpMyAdmin) avec les     ##
##            dernières versions.                                            ##
##                                                                           ##
## Date : 16/01/2021                                                         ##
##                                                                           ##
###############################################################################

# Vérification si on est root
if [ "$(whoami)" != "root" ]; then
    SUDO=sudo
fi

# Activer l'arrêt en cas d'erreur
set -e

# Variables
FICHIER_DE_LOG="$HOME/post-install.log"
MOT_DE_PASSE_ADMIN_MARIADB="P@ssw0rdMariaDB"
MOT_DE_PASSE_PMA="motdepasse"
MOT_DE_PASSE_WPUSER="Sio1234*"
DEPOT_GITHUB="https://github.com/Gorz07/b15wp2cloud.git"

# Création du fichier de log
touch $FICHIER_DE_LOG

suiviInstallation() {
    echo "# $1"
    ${SUDO} echo "# $1" &>>$FICHIER_DE_LOG
    ${SUDO} bash -c 'echo "#####" `date +"%d-%m-%Y %T"` "$1"' &>>$FICHIER_DE_LOG
}

toutEstOK() {
    echo -e "  '--> \e[32mOK\e[0m"
}

erreurOnSort() {
    echo -e "\e[41m" `${SUDO} tail -1 $FICHIER_DE_LOG` "\e[0m"
    echo -e "  '--> \e[31mUne erreur s'est produite\e[0m, consultez le fichier \e[93m$FICHIER_DE_LOG\e[0m"
    exit 1
}

# Mise à jour des paquets
suiviInstallation "Mise à jour des paquets"
${SUDO} apt-get -y update &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort 
${SUDO} apt-get -y upgrade &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Installation des dépendances
suiviInstallation "Installation des dépendances"
${SUDO} apt-get -y install apache2 mariadb-server php libapache2-mod-php php-mysql git &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Démarrer et activer MariaDB
suiviInstallation "Configuration de MariaDB"
${SUDO} systemctl start mariadb
${SUDO} systemctl enable mariadb

# Création de la base de données et de l'utilisateur WordPress
suiviInstallation "Création de la base de données WordPress et utilisateur"
${SUDO} mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS wordpress DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY '$MOT_DE_PASSE_WPUSER';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
EOF
toutEstOK

# Clonage du dépôt GitHub
suiviInstallation "Clonage du dépôt WordPress"
cd /var/www/html
${SUDO} git clone $DEPOT_GITHUB wordpress &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Vérification de la présence du fichier restore_wordpressbdd.sql
suiviInstallation "Vérification du fichier de restauration"
if [ -f /var/www/html/wordpress/restore_wordpressbdd.sql ]; then
    toutEstOK
else
    erreurOnSort
fi

# Restauration de la base de données WordPress
suiviInstallation "Restauration de la base de données WordPress"
${SUDO} mariadb -u root wordpress < /var/www/html/wordpress/restore_wordpressbdd.sql &>>$FICHIER_DE_LOG && toutEstOK || erreurOnSort

# Configuration Apache
suiviInstallation "Configuration Apache"
${SUDO} sed -i "s|DocumentRoot /var/www/html|DocumentRoot /var/www/html/wordpress|" /etc/apache2/sites-available/000-default.conf
${SUDO} systemctl restart apache2 && toutEstOK

# Permissions correctes sur les fichiers WordPress
suiviInstallation "Configuration des permissions WordPress"
${SUDO} chown -R www-data:www-data /var/www/html/wordpress
${SUDO} chmod -R 755 /var/www/html/wordpress && toutEstOK

# Fin de l'installation
suiviInstallation "Le serveur est prêt !"
exit 0

