# Dotfiles

Personal configuration files for Linux desktop and CLI tools.  
These dotfiles are managed with [GNU Stow](https://www.gnu.org/software/stow/) for easy symlink management and portability.

---

## Requirements

- **Tested on:**  
  - **Debian** (and derivatives)
  - **XFCE4** desktop environment

---

## Dependencies


- **stow** – Symlink manager for dotfiles
- **fish** – Friendly interactive shell
- **bash** – GNU Bourne Again SHell
- **git** – Version control system
- **curl** – Command-line tool for transferring data with URLs
- **wget** – Network downloader
- **build-essential** – Compilation tools (gcc, make, etc.)
- **gcc** – GNU C compiler
- **libx11-dev** – X11 client-side library (for building X11 apps/scripts)
- **mpv** – Media player
- **polybar** – Status bar for window managers
- **sxhkd** – Simple X hotkey daemon
- **rofi** – Window switcher, run launcher, and dmenu replacement
- **thunar** – XFCE file manager
- **xfce4-goodies** – Extra plugins and utilities for XFCE4
- **pactl** – PulseAudio command-line utility (audio control)
- **libnotify-bin** – Desktop notification tool (`notify-send`)
- **network-manager** – Network management daemon and CLI
- **xclip** – Command-line clipboard manager
- **dircolors** – Color setup for GNU ls and related tools
- **bash-completion** – Programmable completion for Bash
- **wmctrl** – Command-line tool to interact with X window manager
- **xkill** – Kill X11 client windows by clicking
- **fonts-jetbrains-mono** – JetBrains Mono font
- **fonts-font-awesome** – Font Awesome icon font
- **fonts-noto-color-emoji** – Emoji font
- **pkg-config** – Helper tool for compiling applications and libraries
- **feh** – Lightweight image viewer (used for setting wallpapers)
- **pulseaudio-utils** – PulseAudio utilities (includes pactl, etc.)
- **jq** – Command-line JSON processor
- **fzf** – Command-line fuzzy finder
- **picom** – X compositor for transparency and effects
- **diodon** – Clipboard manager for X
- **kitty** – Fast, feature-rich, GPU-based terminal emulator

**Manual/External Install:**

- **Nerd Fonts** – Patched fonts with icons for Polybar, Rofi, Starship, and terminal prompts ([nerdfonts.com](https://www.nerdfonts.com/))
- **starship** – Fast, customizable, minimal shell prompt ([starship.rs](https://starship.rs))
- **pyenv** – Python version management tool ([github.com/pyenv/pyenv](https://github.com/pyenv/pyenv))
- **fnm** – Fast Node.js version manager ([github.com/Schniz/fnm](https://github.com/Schniz/fnm))
- **ble.sh** – Advanced command line editor for Bash ([github.com/akinomyoga/ble.sh](https://github.com/akinomyoga/ble.sh))
- **uv** – Fast Python package/dependency manager ([github.com/astral-sh/uv](https://github.com/astral-sh/uv))
- **oh-my-fish** (optional) – Framework for managing Fish shell configuration and plugins ([github.com/oh-my-fish/oh-my-fish](https://github.com/oh-my-fish/oh-my-fish))

---

## Setup

1. **Clone this repo:**
   ```sh
   git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **Symlink configs with Stow:**
   ```sh
   stow bash
   stow fish
   stow polybar
   stow sxhkd
   stow rofi
   stow mpv
   stow starship
   stow autostart
   stow picom
   # ...add more as needed
   ```

   Or use the provided script:
   ```sh
   ./stow-all.sh
   ```

3. **Install all required packages and tools** (see above).

4. **Restart your shell or log out/in** to apply changes.

---

## Notes

- All configs use `$HOME` for portability where possible.
- Some files (like `.desktop` in autostart) require absolute paths; update these if your username or directory changes.
- Review and edit scripts in `.local/bin/` as needed for your workflow.
- If you add new configs, mirror the directory structure for Stow.

---

## Security

- Do **not** store secrets or passwords in your dotfiles.
- Only install external tools from their official sources.
- Ensure your dotfiles and scripts are not world-writable.
- If you accidentally share copyrighted material, remove it immediately.

---