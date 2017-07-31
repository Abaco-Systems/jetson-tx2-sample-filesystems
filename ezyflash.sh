##
## Abaco Systems - GVC1000 flashing wizard (Unofficial)
##
## This script is an interactive installer for the GVC1000 and Jetson TX2 Evaluation 
## boards. It is provided for refferance only and comes with absolutly no warrenty 
## or support.
##
## Please use the production SDK for official L4T developemnt and support.
##

#!/bin/bash

# Uncomment the line below for the runtime libraries for production system

export TEGRA_KERNEL_OUT=build

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"
LC_ALL="C.UTF-8"
SELF=$0
SECONDS=0
TIMEOUT=30
DATE=$(date "+%s")
CORES=$(nproc --all)
BOARD=jetson-tx2
RELEASE="unknown";
UBUNTU_RELEASE_VERSION=16.04.02
ABACO_TITLE="Easy Tegra TX2 System Setup"
OS="Ubuntu Base 16.04.2"
UBUNTU_BASE=" - Ubuntu Base 16.04.2"
PREPARE="Preparing Filesystem..."
CONFIGURE="Configuring Filesystem..."
PROGRESS_HEIGHT=7
ROOT=$PWD
KERNEL=kernel/kernel-4.4
KERNEL_PATH=kernel/kernel-4.4/build/arch/arm64/boot
KERNEL_IMAGE=kernel/kernel-4.4/build/arch/arm64/boot/Image
HOSTNAME=tx2

select_release()
{
  REL=$1

  case $REL in
  R27_1)
    RELEASE="R27.1";
    NVIDIA_PATH=developer2.download.nvidia.com/embedded/L4T/r27_Release_v1.0
    SAMPLE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_R27.1.0_aarch64.tbz2
    L4T_RELEASE_PACKAGE=Tegra186_Linux_R27.1.0_aarch64.tbz2
    L4T_SOURCES=r27.1.0_sources.tbz2
    L4T_COMPILER=gcc-4.8.5-aarch64.tgz
    L4T_DOCS=Tegra_Linux_Driver_Package_Documents_R27.1.tar
    KERNEL_SOURCES_DIR=""
    KERNEL_SOURCES=kernel_src.tbz2
    ;;
  R28_1)
    # http://developer2.download.nvidia.com/embedded/L4T/r28_Release_v1.0/BSP/source_release.tbz2
    RELEASE="R28.1";
    NVIDIA_PATH=developer2.download.nvidia.com/embedded/L4T/r28_Release_v1.0
    SAMPLE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_R28.1.0_aarch64.tbz2
    L4T_RELEASE_PACKAGE=Tegra186_Linux_R28.1.0_aarch64.tbz2 
    L4T_SOURCES=source_release.tbz2
    L4T_COMPILER=gcc-4.8.5-aarch64.tgz
    L4T_DOCS=NVIDIA_Tegra_Linux_Driver_Package.tar
    KERNEL_SOURCES_DIR=sources
    KERNEL_SOURCES=kernel_src-tx2.tbz2
    ;;
  esac

  # Common downloads  
  SAMPLE_BASE_FS_PACKAGE=ubuntu-base-16.04.2-base-arm64.tar.gz
  PACKLUNCH_FILENAME="packlunch-${RELEASE}.cfg"
}

cleanup() {
  rm -f /tmp/menu.sh* > /dev/null
  rm -f /tmp/build.txt > /dev/null
  rm -f /tmp/file.txt > /dev/null
}

abort() {
  dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "Abort" \
    --msgbox "Board not flashed please run this script again!!!" 6 60
  cleanup
  clear
}

check_connected() {
  lsusb | grep -i nvidia  &> /dev/null
  NVIDIA_READY=$?
  if ((${NVIDIA_READY} > 0)); then
    NVIDIA_READY="\Z1WARNING: Could not find nVidia device on USB. Please run 'lsusb' and make sure your device is connected to the host before continuing.\Z0\n"
  else
    NVIDIA_READY="\Z2Found nVidia device on USB ready to flash.\Z0\n"
  fi

  dialog --colors --backtitle "${ABACO_TITLE}"  \
    --msgbox "Target check:\n\n${NVIDIA_READY}\n" 9 60
}

clean() {
  cd ${ROOT}/Linux_for_Tegra/rootfs &> /dev/null
  chroot . /bin/bash -c "apt-get clean &> /dev/null"
  chroot . /bin/bash -c "rm -rf /var/lib/apt/lists/*"
  chroot . /bin/bash -c "rm -f /usr/bin/qemu-aarch64-static"
  cd - &> /dev/null
}

flash_filesystem() {
  cd ${ROOT}/Linux_for_Tegra  &> /dev/null

  FLASH_OK=false;
  while [ $FLASH_OK == false ]; do
    lsusb | grep -i nvidia &> /dev/null

    NVIDIA_READY=$?
    if ((${NVIDIA_READY} > 0)); then
      NVIDIA_READY="\Z1CAUTION: Could not find nVidia device on USB. Please run 'lsusb' and make sure your device is connected to the host before continuing.\Z0\n"
    else
      NVIDIA_READY="\Z2NOTE: Found nVidia device on USB ready to flash.\Z0\n"
    fi

    dialog --colors --backtitle "${ABACO_TITLE}"  \
      --help-button --help-label "Re-check" --yesno "Are you ready to flash the filesystem?\n\n${NVIDIA_READY}\n" 9 60

    response=$?
    case $response in
       0) clean; # Last thing we do is clean the filesystem
          sudo ./flash.sh $1 ${BOARD} mmcblk0p1 2> /dev/null | dialog --colors --backtitle "${ABACO_TITLE} - \Z1Please wait for flashing to complete\Z0" --exit-label 'Exit when flash completes' --programbox "Flashing target..." 25 85 2> /dev/null; FLASH_OK=true;;
       1) abort; clear; exit -1;;
       255) echo "[ESC] key pressed.";;
    esac
   done
  cd - &> /dev/null
}

check_for_kernel_update() {
  cd ${ROOT}/Linux_for_Tegra  &> /dev/null
  if [ -f ../$KERNEL_PATH/Image ]; then
    d=$(stat -c%y ../$KERNEL_PATH/Image | cut -d'.' -f1)
    dialog --colors --backtitle "${ABACO_TITLE}${VERSION}"  \
      --yesno "Rebuilt kernel image detected, would copy this into the filesystem?\n\n           KERNEL BUILT : \Z6$d\Zn" 9 60

    response=$?
    case $response in
       0) cp $ROOT/$KERNEL_PATH/Image ./kernel/Image &> /dev/null
          cp $ROOT/$KERNEL_PATH/zImage ./kernel/zImage &> /dev/null
          cp $ROOT/$KERNEL/$TEGRA_KERNEL_OUT/modules/kernel_supplements.tbz2 ./kernel/kernel_supplements.tbz2 &> /dev/null
          cp $ROOT/$KERNEL/$TEGRA_KERNEL_OUT/arch/arm64/boot/dts/* ./kernel/dtb &> /dev/null
          ;;
    esac
  fi

  cd - &> /dev/null
}

ask_open_shell() {
  cd ${ROOT}$1 &> /dev/null
  dialog --defaultno --colors --backtitle "${ABACO_TITLE}${VERSION}"  \
    --yesno "Do you want to open a filesystem terminal?\n\nNOTE: This can be usefull for manually configuring your filesystem prior to flashing. $2\Zn\n" 10 60

  response=$?
  case $response in
     0) cd $ROOT/Linux_for_Tegra/rootfs &> /dev/null;gnome-terminal -e "bash -c \"printf 'Abaco QEMU shell for $OS\nPlease make any modifications then type exit to finish:\n\n';LANG=en_US.UTF-8 chroot . /bin/bash\"" &> /dev/null
        cd ..
        dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "QEMU filesystem shell open..." --msgbox "Press OK when you have finished modifying the filesystem." 5 70
        ;;
  esac
  cd - &> /dev/null
}

#
# https://developer.nvidia.com/embedded/linux-tegra (Stable)
#
setup_l4t () {
  OS="Ubuntu 16.04 LTS (L4T ${RELEASE})"
  USER=nvidia
  PASSWORD=nvidia
  VERSION=" - $OS"

  cmd="dialog --backtitle \"${ABACO_TITLE}\"  \
--title \"Select your filesystem\" \
--no-cancel \
--menu \"You can use the UP/DOWN arrow keys, the first letter of the choice as a hot key.\" 16 65 6 \
cmdline \"Minimal command line (with networking)\" \
xfce4 \"Xfce4 Desktop Environment (with networking)\" \
lxde \"Lxde Desktop Environment (with networking)\" \
nvidia \"L4T R28.1 Full Unity Desktop\" \
${FLASH_QUICK} ${FLASH_QUICK_MENU} \
Exit \"Exit to the shell\"  2> \"${INPUT}\""

  eval $cmd

  menuitem=$(cat ${INPUT})

  # make decsion 
  case $menuitem in
    cmdline) DOWNLOAD_PATH=github.com/Abaco-Systems/tx2-sample-filesystems/releases/download/R28_1;
             DOWNLOAD_FS=Tegra_Linux_Sample-Root-Filesystem_Debootstrap_cmdline_aarch64.tbz2;
             VERSION=" - Github Debootstrap command line Ubuntu (xenial)"
             ;;
    xfce4) DOWNLOAD_PATH=github.com/Abaco-Systems/tx2-sample-filesystems/releases/download/R28_1;
           DOWNLOAD_FS=Tegra_Linux_Sample-Root-Filesystem_Debootstrap_xfce4_aarch64.tbz2;
           VERSION=" - Github Debootstrap Xfce4 line Ubuntu (xenial)"
           ;;
    lxde) DOWNLOAD_PATH=github.com/Abaco-Systems/tx2-sample-filesystems/releases/download/R28_1;
          DOWNLOAD_FS=Tegra_Linux_Sample-Root-Filesystem_Debootstrap_lxde_aarch64.tbz2;
           VERSION=" - Github Debootstrap Lxdes line Ubuntu (xenial)"
          ;;
    nvidia) DOWNLOAD_PATH=${NVIDIA_PATH}/BSP;DOWNLOAD_FS=${SAMPLE_FS_PACKAGE};;
    Exit) abort;exit;;
  esac

  if [ -d "Linux_for_Tegra" ]; then
    echo '15' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${PREPARE}" --gauge 'Removing old Files.' ${PROGRESS_HEIGHT} 75 0
    rm -rf Linux_for_Tegra/ &> /dev/null
  fi

  echo '20' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${PREPARE}"  --gauge "Downloading filesystem ${DOWNLOAD_FS}" ${PROGRESS_HEIGHT} 75 0
  wget -nc -q http://${DOWNLOAD_PATH}/${DOWNLOAD_FS}
  DOWNLOAD_FS=${ROOT}/${DOWNLOAD_FS}

  echo '40' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${PREPARE}" --gauge "Downloading drivers ${L4T_RELEASE_PACKAGE}" ${PROGRESS_HEIGHT} 75 0
  wget -nc -q http://${NVIDIA_PATH}/BSP/${L4T_RELEASE_PACKAGE}

  echo '60' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${PREPARE}" --gauge "Expanding ${L4T_RELEASE_PACKAGE}" ${PROGRESS_HEIGHT} 75 0
  tar xpf ${L4T_RELEASE_PACKAGE} &> /dev/null


  cd ./Linux_for_Tegra/rootfs/  &> /dev/null
  TMP=${DOWNLOAD_FS##*/} 
  echo '80' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${PREPARE}" --gauge "Expanding ${TMP}" ${PROGRESS_HEIGHT} 75 0
  tar xpf ${DOWNLOAD_FS}

  cd ..
  echo '90' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Applying binaries...' ${PROGRESS_HEIGHT} 75 
  ./apply_binaries.sh > /dev/null
  echo '95' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Setting up QEMU emulator...' ${PROGRESS_HEIGHT} 75 
  cp /usr/bin/qemu-aarch64-static ./rootfs/usr/bin/. &> /dev/null

  ## Preload the nVidia librarys Packlunch
  select_packlunch $PACKLUNCH_FILENAME

  # If the kernel has been rebuilt offer to copy the Image in
  check_for_kernel_update
  
  cd $ROOT/Linux_for_Tegra/rootfs &> /dev/null
  echo '10' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Enabling other sources...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "sed -i 's/# deb http/deb http/g' /etc/apt/sources.list"
  echo '20' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Updating apt-get...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "apt-get update > /dev/null"
  echo '30' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Installing packages...' ${PROGRESS_HEIGHT} 70 
  install_packlunch
    
  # Offer to open a QEMU chroot shell for manual probing of filesystem
  ask_open_shell /Linux_for_Tegra/rootfs 

  # Now flash the target
  flash_filesystem

  # Basic usage info (anonymous)
  wget -O /dev/null "http://dweet.io/dweet/for/abaco-l4t-setup?OS=Linux4Tegra&Version=17.01Setup_Time=$SECONDS&Date=$DATE"  &> /dev/null

  dialog --backtitle "${ABACO_TITLE}${VERSION}" \
  --colors \
  --title "Target system should be rebooting now..." \
  --msgbox "\n
Filesystem setup complete you can now login using:\n
   username:\Zb\Z0${USER}\Zn\n
   password:\Zb\Z0${PASSWORD}\Zn\n\n
If the network device is not working you will need to rebuild\n
the kernel to include your device.\n
\n\n"  16 70
  clear
}


check_setup() {
  if [ "$EUID" -ne 0 ]
  then 
    echo "Please run as root"
    exit -1
  fi

  # Check that we can run the menu system
  if which dialog > /dev/null
  then
    # Found so do nothing
    echo "Ok lets continue" &> /dev/null
  else
    read -p "Install dialog command (y/n)?" choice
    case "$choice" in 
      y|Y ) sudo apt-get -qqy install dialog;;
      n|N ) echo "Command required quitting..."; exit;;
      * ) echo "invalid";;
    esac
  fi
}

#
# Download and rebuild the kernel source
#
rebuild_kernel() {
  export CROSS_COMPILE=$ROOT/install/bin/aarch64-unknown-linux-gnu-
  export ARCH=arm64
  CONFIG=tegra18_defconfig
  VERSION=" - Kernel-4.4"
  BUILD="Configuring host build system"

  # Get the kernel source for our board
  echo '10' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Removing old sources...' ${PROGRESS_HEIGHT} 70 
  rm -rf install
  rm -rf kernel
  rm -rf sources
  rm -rf nvl4t_docs
  rm -rf build
  rm -rf hardware
  echo '15' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Getting kernel sources $L4T_SOURCES...' ${PROGRESS_HEIGHT} 70 
  wget -nc -q http://${NVIDIA_PATH}/BSP/${L4T_SOURCES}
  echo '30' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Getting toolchain...' ${PROGRESS_HEIGHT} 70 
  wget -nc -q http://${NVIDIA_PATH}/BSP/${L4T_COMPILER}
  echo '50' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Getting documentation...' ${PROGRESS_HEIGHT} 70 
  wget -nc -q http://${NVIDIA_PATH}/Docs/${L4T_DOCS}
  echo '60' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Unpacking sources archive...' ${PROGRESS_HEIGHT} 70 
  case $REL in
  R27_1)
    tar xjf ${L4T_SOURCES} ${KERNEL_SOURCES}
    ;;
  R28_1)
    tar xjf ${L4T_SOURCES} ${KERNEL_SOURCES_DIR}/${KERNEL_SOURCES}
    ;;
  esac

  echo '70' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Unpacking compiler archive...' ${PROGRESS_HEIGHT} 70 
  tar xfz ${L4T_COMPILER}
  echo '80' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Unpacking documentation archive...' ${PROGRESS_HEIGHT} 70 
  tar xf ${L4T_DOCS}
  echo '90' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Unpacking kernel archive...' ${PROGRESS_HEIGHT} 70 
  case $REL in
  R27_1)
    tar xjf ${KERNEL_SOURCES}
    ;;
  R28_1)
    tar xjf ${KERNEL_SOURCES_DIR}/${KERNEL_SOURCES}
    ;;
  esac

  if [ -f ${L4T_DOCS} ]; then
    dialog --colors --defaultno --backtitle "${ABACO_TITLE}${VERSION}"  \
      --yesno "Do you want to open the kernel documentation?\n" 6 60

    response=$?
    case $response in
       0) firefox $ROOT/nvl4t_docs/index.html &> /dev/null &;;
    esac
  fi

  # create .config the offer to edit it (menuconfig)
  cd $ROOT/$KERNEL
  mkdir $TEGRA_KERNEL_OUT &> /dev/null
  make mrproper 

  BOX_TYPE=--programbox

  make -j$CORES O=$TEGRA_KERNEL_OUT ${CONFIG} 2> /dev/null | dialog --colors --backtitle "${ABACO_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Building ${CONFIG}..."  25 85

  dialog --colors --defaultno --backtitle "${ABACO_TITLE}${VERSION}"  \
    --yesno "Do you want to run menuconfig?\n" 6 60

  response=$?
  MENUCONFIG="Setting up Menuconfig"
  case $response in
     0) echo '50' | dialog --backtitle "${ABACO_TITLE}${VERSION}" --title "${MENUCONFIG}" --gauge 'Installing libcursers...' ${PROGRESS_HEIGHT} 70 
        sudo apt-get -qqy install libncurses5-dev &> /dev/null  # cant build menusystem without this on 16.04 LTS 
        make menuconfig KCONFIG_CONFIG=$TEGRA_KERNEL_OUT/.config 2> /dev/null
        ;;
  esac

  dialog --backtitle "${ABACO_TITLE}${VERSION}" \
--title "Build Environment" \
--colors \
--ok-label "Build Kernel" \
--msgbox "CROSS_COMPILE=${CROSS_COMPILE}
TEGRA_KERNEL_OUT=$TEGRA_KERNEL_OUT\n
ARCH=$ARCH\n
CONFIG=$CONFIG\n
KERNEL=/$KERNEL\n" 10 70

  KBUILD_START=$SECONDS
  make -j$CORES O=$TEGRA_KERNEL_OUT zImage 2> /dev/null | dialog --colors --backtitle "${ABACO_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Building zImage..."  25 85
  make -j$CORES O=$TEGRA_KERNEL_OUT dtbs 2> /dev/null | dialog --colors --backtitle "${ABACO_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Building dtbs..."  25 85 
  make -j$CORES O=$TEGRA_KERNEL_OUT modules 2> /dev/null  | dialog --colors --backtitle "${ABACO_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Building modules..."  25 85  
  mkdir $TEGRA_KERNEL_OUT/modules
  make -j$CORES O=$TEGRA_KERNEL_OUT modules_install INSTALL_MOD_PATH=./modules | dialog --colors --backtitle "${ABACO_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Installing Modules..."  25 85
  cd $TEGRA_KERNEL_OUT/modules &> /dev/null
  tar --owner root --group root -cjf kernel_supplements.tbz2 lib/modules &> /dev/null
  cd - &> /dev/null
  KBUILD_END=$SECONDS
  KBUILD_TIME=$(($KBUILD_END - $KBUILD_START))

  # Basic usage info (anonymous)
  wget -O /dev/null "http://dweet.io/dweet/for/abaco-kernel-setup?OS=Ubuntu_Base&Version=16.04.2&Setup_Time=$SECONDS&Build_Time=$KBUILD_TIME&Date=$DATE"  &> /dev/null

  dialog --backtitle "${ABACO_TITLE}${VERSION}" \
--title "Compilation Complete (${SECONDS}s)" \
--colors \
--ok-label "Quit" \
--msgbox "
Copy the kernel to your target /boot :\n\n
  \Z6./kernel/kernel-4.4/build/arch/arm64/boot/Image\Zn\n
  \Z6./kernel/kernel-4.4/build/arch/arm64/boot/zImage\Zn\n
  \Z6./kernel/kernel-4.4/build/modules/kernel_supplements.tbz2\Zn\n\n
To remove downloads type :\n
  \Z6$SELF clean\Zn\n
  \Z6$SELF kclean (remove kernel dir only)\Zn\n\n
To finish desktop installation please run ./complete_desktop_install.sh on target." 14 70
  cd - &> /dev/null
  cleanup
  clear
}

##
## Main scripting block
##   Check filesystem choice and invoke setup. This script will:
##     * Download the neccessary files
##     * Expand the archives
##     * Do any filesystem configuration
##     * Apply nVidia binaries
##     * Flash the image to the target
##

# Check for non interactive commands

if [ "$1" = "clean" ]
then
  echo Removing file system directory...
  rm -f ${SAMPLE_FS_PACKAGE}
  rm -f ${SAMPLE_BASE_FS_PACKAGE}
  rm -f ${L4T_RELEASE_PACKAGE}
  rm -rf Linux_for_Tegra/
  rm -rf install
  rm -rf kernel
  rm -rf nvl4t_docs
  rm -rf build
  rm -rf hardware
  rm -f *.tar
  rm -f *.tgz
  rm -f *.tbz2
  rm -f *.txt
  rm -f *.html
  echo Done.
  exit 
fi

if [ "$1" = "kclean" ]
then
  echo Removing kernel directory...
  rm -rf kernel
  echo Done.
  exit
fi

if [ "$1" = "remove" ]
then
  echo Removing install dependancies...
  apt-get -qqy remove libncurses5-dev dialog
  apt -qqy autoremove
  echo Done.
  exit
fi

if [ "$1" = "create" ]
then
  echo Creating template $PACKAGES_FILENAME...
  create_packages $PACKAGES_FILENAME
  echo Done.
  exit
fi

check_setup

dialog --backtitle "${ABACO_TITLE}" \
--title "nVidia TX2 device setup tool" \
--colors \
--ok-label "Install R28.1" \
--extra-button \
--extra-label "Install R27.1" \
--yesno " \n
TX2 build and flash script \n
    ross.newman@abaco.com (Field Applications Engineer) \n
\n
Script to download and flash TX2 Tegra sample file systems.\n
   $ abaco-flash.sh (interactive setup)\n
   $ abaco-flash.sh clean (remove all temporary files)\n
   $ abaco-flash.sh kclean (remove kernel temporary file)\n
   $ abaco-flash.sh remove (remove apt-get installer packages)\n
   $ abaco-flash.sh create (create template packages file)\n
\n
Please place board into recovery mode and connect to (this) host machine.\n\n
\Z3WARNING: Computer must be connected to the internet to download required packages\Z0\n\n
\Z1NOTE: This script is provided without any warrenty or support what so ever, for refference only.\Z0\n" 23 75

response=$?

case $response in
   0) select_release R28_1;;
   1) abort; clear; exit -1;;
   3) select_release R27_1;;
   255) abort; clear; echo "[ESC] key pressed."; exit -1;;
esac

### display main menu ###

if [ -f ./Linux_for_Tegra/bootloader/system.img ];then
  FLASH_QUICK_MENU='"Quickly flash the last system.img"'
  FLASH_QUICK=quick
else
  FLASH_QUICK_MENU=
  FLASH_QUICK=''
fi

if [ -f ./Linux_for_Tegra/bootloader/tegraflash.py ];then
# The clone function appears to no longer work on the TX2 so removing it for now
#  BACKUP_MENU='"Create a backup image"'
#  BACKUP=backup
#  RESTORE_MENU='"Quickly flash the last system.img"'
#  RESTORE=restore
  dummy=0
fi
INPUT=/tmp/menu.sh.$$

# Not supported
# arch \"Install the latest version of archlinux (Alpha)\" \

cmd="dialog --backtitle \"${ABACO_TITLE}\"  \
--title \"Select your filesystem\" \
--no-cancel \
--menu \"You can use the UP/DOWN arrow keys, the first letter of the choice as a hot key.\" 16 65 6 \
flash \"Flash a filesystem\" \
kernel \"Rebuild the Linux kernel\" \
${FLASH_QUICK} ${FLASH_QUICK_MENU} \
Exit \"Exit to the shell\"  2> \"${INPUT}\""

eval $cmd

menuitem=$(cat ${INPUT})

# make decsion 
case $menuitem in
  flash) setup_l4t;;
  kernel) rebuild_kernel;;
  quick) cd $ROOT/Linux_for_Tegra &> /dev/null;flash_filesystem -r;cd ..;clear;;
  Exit) abort;exit;;
esac

cleanup



