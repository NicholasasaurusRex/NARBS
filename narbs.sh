#!/bin/sh
#############################################
# Nick's Archlinux Restore Bootstrap Script #
#############################################

### OPTIONS

while getopts ":a:r:b:p:h" o
  do case "${o}" in

    h) printf "\nUsage:\n\n    narbs [option] [file]\n    narbs [option] [url]\n    narbs [option] [branch]\n    narbs [option] [branch] [option] [url] [option] [file]\n\n    Example: narbs -b master -r https://git.com/name/file.git -p /home/name/file.csv\n

    Options:\n
        -b        Repository branch (e.g. master, dev, test,)
        -r        Configuration files repository (url or file)
        -p        Dependencies and programs csv (url or file)
        -h        Show this message\n\n" && exit ;;

  	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
  	b) repobranch=${OPTARG} ;;
  	p) progsfile=${OPTARG} ;;
  	a) aurhelper=${OPTARG} ;;
  	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;

esac done



### VARIABLES

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/NicholasasaurusRex/dotFiles.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/NicholasasaurusRex/NARBS/master/progs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"
[ -z "$repobranch" ] && repobranch="master"



### SUPPORTING FUNCTIONS

installpkg(){ pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ;}

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

aurinstall() { \
	dialog --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 5 70
	echo "$aurinstalled" | grep -q "^$1$" && return
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
	}


gitmakeinstall() {
	progname="$(basename "$1" .git)"
	dir="$repodir/$progname"
	dialog --title "LARBS Installation" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return ;}


pipinstall() { \
	dialog --title "LARBS Installation" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
	command -v pip || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
	}


maininstall() { # Installs all needed programs from main repo.
	dialog --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	installpkg "$1"
	}


### MAIN FUNCTIONS

#(1)
welcomemsg() {
  dialog --title "Nick's Archlinux Restore Bootstrap Script." --yes-label "Enter" --no-label "Exit" --yesno "\\n\\nThis is an automated installation script used to efficiently restore Archlinux after reinstallation." 10 55
}


#(2)
getuserandpass() { \
# Prompts user for new username an password.
	name=$(dialog --inputbox "\\nEnter the user account." 10 50 3>&1 1>&2 2>&3 3>&1) || exit
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(dialog --no-cancel --inputbox "\\nUsername not valid." 10 50 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "\\nEnter a password." 10 50 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "\\nRetype password." 10 50 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "\\nPasswords do not match.\\nEnter password again." 10 50 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "\\nRetype password." 10 50 3>&1 1>&2 2>&3 3>&1)
	done ;}


#(3)
usercheck() { \
	! (id -u "$name" >/dev/null) 2>&1 ||
	dialog --colors --title "Nick's Archlinux Restore Bootstrap Script." --yes-label "ENTER" --no-label "EXIT" --yesno "\\nThe user \`$name\` already exists. Do you wish to \\Zboverwrite\\Zn the settings on this users account?\\n\\nThis will \\Zbnot\\Zn overwrite any documents, videos, pictures, etc." 10 50
	}


#(4)
preinstallmsg() { \
	dialog --title "Nick's Archlinux Restore Bootstrap Script." --yes-label "ENTER" --no-label "EXIT" --yesno "\\n\\nTo continue with the installation hit ENTER if not please EXIT" 10 50 || { clear; exit; }
	}


#(5)
refreshkeys() { \
	dialog --infobox "Refreshing Arch Keyring..." 4 50
	pacman -Q artix-keyring >/dev/null 2>&1 && pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
	pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
	}


#(6)
adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}


#(7)
newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#LARBS/d" /etc/sudoers
	echo "$* #LARBS" >> /etc/sudoers ;}


#(8)
manualinstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[ -f "/usr/bin/$1" ] || (
	dialog --infobox "Installing \"$1\", an AUR helper..." 4 50
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
	cd "$1" &&
	sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp || return) ;}


#(9)
installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
			*) maininstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;}


#(10)
putgitrepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --infobox "Downloading and installing config files..." 4 50
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown -R "$name":wheel "$dir" "$2"
	sudo -u "$name" git clone --recursive -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
	sudo -u "$name" cp -rfT "$dir" "$2"
	}


#(11)
systembeepoff() { dialog --infobox "Turning off the system error beep..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}


#(12)
finalize(){ \
	dialog --title "Nick's Archlinux Restore Bootstrap Script." --msgbox "\\nInstallation complete." 6 50
	}


####################
### SCRIPT START ###
####################

# Check if user is root on Arch distro. Install dialog.
pacman --noconfirm --needed -Sy dialog || error "Are you running this as the root user? Do have an internet connection?"

# Welcome user and pick dotfiles.
#(1)
welcomemsg || error "User exited."

# Get and verify username and password.
#(2)
getuserandpass || error "User exited."

# Give warning if user already exists.
#(3)
usercheck || error "User exited."

# Last chance for user to back out before install.
#(4)
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

# Refresh Arch keyrings.
#(5)
refreshkeys || error "Error automatically refreshing Arch keyring."

for x in curl base-devel git ntp zsh; do
	dialog --title "Nick's Archlinux Restore Bootstrap Script." --infobox "\\nInstalling \`x\`" 5 50
	installpkg "$x"
done

dialog --title "Nick's Archlinux Restore Bootstrap Script." --infobox "\\nSynchronizing system time..." 5 50
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

#(6)
adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
#(7)
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman and yay colorful and adds eye candy on the progress bar because why not.
grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

#(8)
manualinstall $aurhelper || error "Failed to install AUR helper."

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
#(9)
installationloop

dialog --title "Nick's Archlinux Restore Bootstrap Script." --infobox "\\nInstalling \`libxft-bgra-git\`" 5 50
yes | sudo -u "$name" $aurhelper -S xorg-util-macros libxft-bgra-git >/dev/null 2>&1

# Install the dotfiles in the user's home directory
#(10)
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
rm -f "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"
# make git ignore deleted LICENSE & README.md files
git update-index --assume-unchanged "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"

# Most important command! Get rid of the beep!
#(11)
systembeepoff

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# dbus UUID must be generated for Artix runit.
dbus-uuidgen > /var/lib/dbus/machine-id

# Tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

# Fix fluidsynth/pulseaudio issue.
grep -q "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" /etc/conf.d/fluidsynth ||
	echo "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" >> /etc/conf.d/fluidsynth

# Start/restart PulseAudio.
killall pulseaudio; sudo -u "$name" pulseaudio --start

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newperms "%wheel ALL=(ALL) ALL #LARBS
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm"

# Last message! Install complete!
#(12)
finalize
clear

# Copy archFinalize to /home/code
sleep 3
echo " Copying zshrc, archFinalize to /home/$name "
cp /root/archFinalize /home/$name/
cp /root/1-zshr /home/$name/
sleep 2
echo "Exit root user and login with the new user"
