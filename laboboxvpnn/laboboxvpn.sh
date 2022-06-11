#!/bin/bash
#####################################
#       By CLusmi - 11/06/2022      #
# Pour seedbox sur colocation @home #
#####################################

#Controle si ROOT
if [ "$(id -u)" != "0" ]; then
   echo -e "\033[31mCe script doit etre lance en ROOT\033[0m" 1>&2
   exit 1
fi

#Controle présence fichier .ovpn
echo -e "\033[36mVous devez IMPERATIVEMENT uploader votre fichier .ovpn sur le serveur.\033[0m"
echo -e "\033[36mDans ce dossier : /opt/laboboxvpn/MONVPN.ovpn\033[0m"

read -p "Appuyez sur une touche une fois le fichier .ovpn present."

mv /opt/laboboxvpn/*.ovpn /opt/laboboxvpn/docker_apps/rtorrentvpn/config/openvpn/vpn.ovpn
if [ -f "/opt/laboboxvpn/docker_apps/rtorrentvpn/config/openvpn/vpn.ovpn" ];then
	echo -e "\033[32mLe fichier .ovpn est bien present !\033[0m";
		else
		echo -e "\033[31mIl manque le fichier .ovpn comme indique.\033[0m"
		exit 1
fi

#Mise a jour du serveur
apt-get update && apt-get upgrade -y
sleep 5
apt-get install wget apt-transport-https sudo git-core curl zip unzip fail2ban htop nano ffmpeg apache2-utils ipcalc fuse -y

#Variables pour l'ip
ADDRESS=`wget -qO- ipv4.icanhazip.com`

#Récuperation de l'IP LAN_NETWORK pour "rtorrentvpn"
file=/etc/network/interfaces
netmask=$(awk '/netmask/ {print $2}' $file)
ip=$(awk '/address/ {print $2}' $file)
NETWORK=$(ipcalc $ip $netmask | awk '/Network/ {print $2}' | cut -d/ -f1)


##############################
# Activation des modules VPN #
##############################
cp -r /opt/laboboxvpn/divers/etc/modules /etc/modules


############################################
# Installation de Docker et Docker-Compose #
############################################
echo ""
echo -e "\033[36m####  DOCKER & DOCKER-COMPOSE  ####\033[0m"
		echo ""
		read -p "Appuyez sur une touche pour CONTINUER"
		echo ""
		curl -fsSL https://get.docker.com -o get-docker.sh
		sh get-docker.sh
		
        service docker start > /dev/null 2>&1

		curl -s https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url  | grep docker-compose-linux-x86_64 | cut -d '"' -f 4 | wget -qi -
		chmod +x docker-compose-linux-x86_64
		mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
		usermod -aG docker $USER
		newgrp docker
		cd /etc/bash_completion.d/
		curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
#		source /etc/bash_completion.d/docker-compose


############################
# Informations nécessaires #
############################
echo -e "\033[36mSVP, RENSEIGNEZ LES INFORMATIONS et VALIDEZ AVEC LA TOUCHE ENTREE.\033[0m"
echo ""
echo -e "\033[36mNOM du nouvel utilisateur.\033[0m"
read USER
echo -e "\033[36mPASSWORD du nouvel utilisateur.\033[0m"
read PASSWORD
echo -e "\033[36mID du nouvel utilisateur. (exemple : 1500)\033[0m"
echo -e "\033[36m*** ATTENTION, ne pas utiliser un ID existant. ***\033[0m"
echo -e "\033[36mListe des USERS et ID existants.\033[0m"
echo -e "\033[36mTappez votre nouvel ID et validez avec la touche ENTREE.\033[0m"
awk -F: '/\/home/ {printf "%s:%s\n",$1,$3}' /etc/passwd
read UIDGID
echo -e "\033[36mTapez le PORT souhaité pour acces au SFTP.              (exemple : 1100)\033[0m"
read PORTSFTP
echo -e "\033[36mTapez le PORT souhaité pour acces a la WebUI RUTORRENT. (exemple : 1101)\033[0m"
read PORTWEBUIRUTORRENT
echo -e "\033[36mTapez le PORT souhaité pour acces a la WebUI PROWLARR.  (exemple : 1102)\033[0m"
read PORTWEBUIPROWLARR
echo -e "\033[36mTapez le PORT souhaité pour acces a la WebUI RADARR.    (exemple : 1103)\033[0m"
read PORTWEBUIRADARR
echo -e "\033[36mTapez le PORT souhaité pour acces a la WebUI SONARR.    (exemple : 1104)\033[0m"
read PORTWEBUISONARR


##############################
# Installation de la Seedbox #
##############################
echo -e "\033[36m ####  INSTALLATION DE VOTRE SEEDBOX  #### \033[0m"

useradd $USER -p $PASSWORD
usermod -u $UIDGID $USER
groupmod -g $UIDGID $USER
usermod -aG docker $USER

mkdir /home/$USER
mkdir /home/$USER/data
mkdir /home/$USER/data/torrents
mkdir /home/$USER/data/torrents/films
mkdir /home/$USER/data/torrents/series
mkdir /home/$USER/data/torrents/autres

chown -R $USER:$USER /home/$USER/data/	
chown root:$USER /home/$USER
chmod -R 755 /home/$USER

cp -r docker_apps /opt
chown root:root /opt/docker_apps
chmod -R 755 /opt/docker_apps

#Config du docker-compose.yml
sed -i "s|%USER%|$USER|g" /opt/docker_apps/docker-compose.yml
sed -i "s|%PASSWORD%|$PASSWORD|g" /opt/docker_apps/docker-compose.yml
sed -i "s|%PORTWEBUIRUTORRENT%|$PORTWEBUIRUTORRENT|g" /opt/docker_apps/docker-compose.yml
sed -i "s|%PORTWEBUIPROWLARR%|$PORTWEBUIPROWLARR|g" /opt/docker_apps/docker-compose.yml
sed -i "s|%PORTWEBUIRADARR%|$PORTWEBUIRADARR|g" /opt/docker_apps/docker-compose.yml
sed -i "s|%PORTWEBUISONARR%|$PORTWEBUISONARR|g" /opt/docker_apps/docker-compose.yml
sed -i "s|%NETWORK%|$NETWORK|g" /opt/docker_apps/docker-compose.yml
sed -i "s|%UIDGID%|$UIDGID|g" /opt/docker_apps/docker-compose.yml

cd /opt/docker_apps && COMPOSE_HTTP_TIMEOUT=480 docker-compose up -d
	
echo -e "\033[36mAttente de 30 secondes avant mise en service.\033[0m"
seconds=30; date1=$((`date +%s` + $seconds)); 
while [ "$date1" -ge `date +%s` ]; do 
echo -ne "$(date -u --date @$(($date1 - `date +%s` )) +%H:%M:%S)\r"; 
done
echo ""
cd


####################################
# Modification fichier SSHD_CONFIG #
####################################
mv /opt/laboboxvpn/divers/etc/ssh/sshd_config /etc/ssh/sshd_config
sed -i "s/#Port 22/Port $PORTSFTP/g" /etc/ssh/sshd_config
sed -i "s/#PermitRootLogin without-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i "s/#UsePAM yes/UsePAM yes/g" /etc/ssh/sshd_config
echo -e "PasswordAuthentication yes \nMatch User $USER \nChrootDirectory /home" >> /etc/ssh/sshd_config


##########################
# Installation de rClone #
##########################
curl https://rclone.org/install.sh | sudo bash

mkdir /root/.config
mkdir /root/.config/rclone
mv /opt/laboboxvpn/divers/rclone.conf /root/.config/rclone/rclone.conf

mkdir /home/$USER/data/drive

echo -e "rclone mount TEAMDRIVE_COLOC_CRYPT:$USER /home/$USER/data/drive -v --allow-other --allow-non-empty --no-modtime --uid $UIDGID --gid $UIDGID &"
mv /opt/laboboxvpn/divers/mount.sh /mnt/mount.sh

echo -e "\033[36mVeuillez retaper le mot de passe de l'utilisateur précedement créé.\033[0m"
passwd $USER


###################################
# Récapitulatif de l'installation #
###################################
echo ""
echo -e "\033[36m###############################################################\033[0m"
echo ""
echo -e "\033[36m####     L'INSTALLATION DE VOTRE SEEDBOX EST ACCOMPLI      ####\033[0m"
echo -e "\033[36m####  ATTENTION, REBOOT DE VOTRE MACHINE DANS 60 SECONDES  ####\033[0m"
echo ""
echo -e "\033[36m###############################################################\033[0m"
echo ""
echo -e "\033[36m* RUTORRENT   ->    http://$ADDRESS:\033[35m$PORTWEBUIRUTORRENT\033[0m"
echo ""
echo -e "\033[36m* PROWLARR    ->    http://$ADDRESS:\033[35m$PORTWEBUIPROWLARR\033[0m"
echo ""
echo -e "\033[36m* RADARR      ->    http://$ADDRESS:\033[35m$PORTWEBUIRADARR\033[0m"
echo ""
echo -e "\033[36m* SONARR      ->    http://$ADDRESS:\033[35m$PORTWEBUISONARR\033[0m"
echo ""
echo -e "\033[36m* USER     :  $USER      /      PASSWORD  :  $PASSWORD\033[0m"
echo ""
echo -e "\033[36m##############################################################\033[0m"
echo ""
echo -e "\033[32mMerci d'avoir utilisé https://github.com/CLusmi/laboboxvpn\033[0m"
echo ""
echo -e "\033[36mNe pas oublier d'ajouter au 'crontab -e' la ligne suivante :\033[0m"
echo ""
echo -e "\033[36m@reboot cd /mnt && ./mount.sh\033[0m"
echo ""

/etc/init.d/ssh restart

	read -p "Appuyez sur une touche pour redémarrer votre machine"

	echo -e "\033[36mReboot de votre machine dans 15 secondes.\033[0m"
	seconds=15; date1=$((`date +%s` + $seconds)); 
	while [ "$date1" -ge `date +%s` ]; do 
	echo -ne "$(date -u --date @$(($date1 - `date +%s` )) +%H:%M:%S)\r"; 
	done

reboot now