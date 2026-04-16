#!/bin/sh
set -eu

install_dir="$HOME/.local/bin"
install_tool="$install_dir/qmv"
current_shell="${ZSH_VERSION:+zsh}"
current_shell="${current_shell:-${BASH_VERSION:+bash}}"
current_shell="${current_shell:-${SHELL##*/}}"
path_line="export PATH=\"$install_dir:$PATH\""

ensure_line() {
  file="$1"
  line="$2"
  touch "$file"
  if ! grep -Fqx "$line" "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file"
  fi
}

case ":$PATH:" in
  *":$install_dir:"*)
    echo "qmv install directory is already on PATH: $install_dir"
    ;;
  *)
    case "$current_shell" in
      zsh)
        target_rc="$HOME/.zshrc"
        ;;
      bash)
        if [ -f "$HOME/.bash_profile" ] || [ ! -f "$HOME/.bashrc" ]; then
          target_rc="$HOME/.bash_profile"
        else
          target_rc="$HOME/.bashrc"
        fi
        ;;
      *)
        target_rc="$HOME/.profile"
        ;;
    esac

    ensure_line "$target_rc" "$path_line"
    . "$target_rc"
    ;;
esac

hash -r 2>/dev/null || true

if [ ! -x "$install_tool" ]; then
  echo "qmv is not installed at $install_tool. Return to Quick Markdown Viewer and run Install Command Line Tool… again."
  exit 1
fi

case ":$PATH:" in
  *":$install_dir:"*)
    if command -v qmv >/dev/null 2>&1; then
      echo "Success: qmv is available at $(command -v qmv)"
    else
      echo "PATH includes $install_dir and qmv exists at $install_tool, but this shell does not see it yet. Open a new Terminal window and try again."
    fi
    ;;
  *)
    echo "PATH still does not include $install_dir. Open a new Terminal window or add it manually."
    ;;
esac
