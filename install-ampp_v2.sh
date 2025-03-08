#!/bin/bash
###############################################################################
##                                                                           ##
## Auteur : José GIL                                                         ##
##                                                                           ## 
## Synopsis : Script d’installation et de configuration automatique d'un     ##
##            serveur LAMP (Apache, MariaDB, PHP et phpMyAdmin) avec les     ##
##            dernières versions.                                            ##
##                                                                           ##
## Date : 16/01/2021 (Mise à jour 08/03/2025)                                ##
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
MOT_DE_PASSE_WPUSER="Sio1234*"
DEPOT_GITHUB="https://github.com/Gorz07/b15wp2cloud.git"

# Création du fichier de log
touch $FICHIER_DE_LOG

suiviInstallation() {
    echo "# $1"
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
${SUDO} apt-get -y update && toutEstOK || erreurOnSort 
${SUDO} apt-get -y upgrade && toutEstOK || erreurOnSort

# Installation des dépendances
suiviInstallation "Installation des dépendances"
${SUDO} apt-get -y install apache2 mariadb-server php libapache2-mod-php php-mysql git php-mbstring php-xml php-curl php-zip && toutEstOK || erreurOnSort

# Activer PHP sur Apache
suiviInstallation "Activation de PHP sur Apache"
${SUDO} a2enmod php8.3
${SUDO} systemctl restart apache2 && toutEstOK

# Configuration de MariaDB
suiviInstallation "Configuration de MariaDB"
${SUDO} systemctl start mariadb
${SUDO} systemctl enable mariadb

# Création de la base de données et de l'utilisateur WordPress
suiviInstallation "Création de la base de données WordPress et utilisateur"
${SUDO} mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS wordpress DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY '$MOT_DE_PASSE_WPUSER';
CREATE USER IF NOT EXISTS 'wpuser'@'127.0.0.1' IDENTIFIED BY '$MOT_DE_PASSE_WPUSER';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
toutEstOK

# Suppression de l'ancienne installation WordPress si existante
suiviInstallation "Nettoyage de l'ancienne installation de WordPress"
if [ -d "/var/www/html/wordpress" ]; then
    ${SUDO} rm -rf /var/www/html/wordpress
fi

# Clonage du dépôt GitHub
suiviInstallation "Clonage du dépôt WordPress"
cd /var/www/html
${SUDO} git clone $DEPOT_GITHUB wordpress && toutEstOK || erreurOnSort

# Vérification de la présence du fichier restore_wordpressbdd.sql
suiviInstallation "Vérification du fichier de restauration"
if [ ! -f /var/www/html/wordpress/restore_wordpressbdd.sql ]; then
    erreurOnSort
else
    toutEstOK
fi

# Restauration de la base de données WordPress
suiviInstallation "Restauration de la base de données WordPress"
${SUDO} mariadb -u root wordpress < /var/www/html/wordpress/restore_wordpressbdd.sql && toutEstOK || erreurOnSort

# Vérification et configuration de wp-config.php
suiviInstallation "Vérification et configuration du fichier wp-config.php"
if [ ! -f "/var/www/html/wordpress/wp-config.php" ]; then
    ${SUDO} cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    ${SUDO} sed -i "s/database_name_here/wordpress/" /var/www/html/wordpress/wp-config.php
    ${SUDO} sed -i "s/username_here/wpuser/" /var/www/html/wordpress/wp-config.php
    ${SUDO} sed -i "s/password_here/$MOT_DE_PASSE_WPUSER/" /var/www/html/wordpress/wp-config.php
fi
toutEstOK

# Configuration Apache
suiviInstallation "Configuration Apache"
${SUDO} sed -i "s|DocumentRoot /var/www/html|DocumentRoot /var/www/html/wordpress|" /etc/apache2/sites-available/000-default.conf
${SUDO} systemctl restart apache2 && toutEstOK

# Permissions correctes sur les fichiers WordPress
suiviInstallation "Configuration des permissions WordPress"
${SUDO} find /var/www/html/wordpress -type d -exec chmod 755 {} \;
${SUDO} find /var/www/html/wordpress -type f -exec chmod 644 {} \;
${SUDO} chown -R www-data:www-data /var/www/html/wordpress && toutEstOK

# Fin de l'installation
suiviInstallation "Le serveur est prêt !"
exit 0


