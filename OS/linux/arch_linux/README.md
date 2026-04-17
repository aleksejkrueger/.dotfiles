# xinitrc
if [[ "$os" == "linux" ]]; then
  ln -sf $DOTFILES/linux/arch_linux/.xinitrc $HOME/
fi

# pacman.conf
if [[ "$os" == "linux" ]]; then
  sudo ln -sf $DOTFILES/linux/arch_linux/pacman/pacman.conf /etc
fi



# linux exclusives
if [[ "$os" == "linux" ]]; then
  sudo cp $DOTFILES/linux/arch_linux/etc/modprobe.d/nobeep.conf /etc/modprobe.d/
  sudo cp $DOTFILES/linux/arch_linux/etc/X11/xorg.conf.d/20-keyboard.conf /etc/X11/xorg.conf.d/
fi