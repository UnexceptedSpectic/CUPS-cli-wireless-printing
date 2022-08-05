#!/bin/sh

#script to install cups server on ubuntu

#any error will cause the shell script to exit
set -e

#user message
echo
echo "If script does not exit with the message 'Success!', something went wrong"
echo

#update package index
sudo apt update && sudo apt upgrade -y

#package installation; last two prevent 'filter failed' error - read more at https://wiki.archlinux.org/index.php/CUPS/Troubleshooting#CUPS:_.22Filter_failed.22
sudo apt install cups foomatic-db-compressed-ppds jq -y

#add and modify printer
printer_uri=$(/usr/sbin/lpinfo -v | grep usb | awk -F ' ' '{print $2}' | tail -n 1)
printer_name="HP_Color_LaserJet_CP1215"
printer_location="Badzyukh_Loft"

/usr/sbin/lpadmin -p $printer_name -E -v $printer_uri -L $printer_location -P ./HP_Color_LaserJet_CP1215.ppd
lpoptions -d $printer_name

#config backup
sudo cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.original
sudo chmod a-w /etc/cups/cupsd.conf.original

#permissions for user
sudo usermod -aG lpadmin $USER
sudo cupsctl --remote-admin

#config mod
pattern="run"
ip="$(hostname -I | sed -e 's/[[:space:]]*$//')"
replace="Listen "$ip":631"
sudo sed -i "/${pattern}/a${replace}" /etc/cups/cupsd.conf

#restart avahi and CUPS
sudo systemctl restart avahi-daemon
sudo systemctl restart cups.service

#add airprint support
# https://wiki.archlinux.org/title/avahi
# https://wiki.debian.org/CUPSAirPrint
sudo apt install -y python3 python3-pip virtualenv
cd ~ && mkdir airprint_install && cd airprint_install
wget https://raw.githubusercontent.com/UnexceptedSpectic/airprint-generate/master/airprint-generate.py
virtualenv -p python3 env
. env/bin/activate
pip install pycups
python airprint-generate.py -d /etc/avahi/services

#el fin de la comedia
echo
echo 'Success!'
echo

#adding the cups printer to windows
#printers & scanners -> add printer or scanner -> the printer that i want isn't listed -> select a shared printer by name -> enter e.g. http://192.168.0.16:631/printers/HP_Color_LaserJet_CP1215
#(as obtained from the url of the printer page on the cups web interface) -> next -> *if connection fails, change computer/workgroup name, reboot, and try again* -> select driver from next window 
#-> print test page