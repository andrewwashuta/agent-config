
# Configure Node to store packages in a directory local to this user
# instead of in a global location.
NPM_PACKAGES=$HOME/.npm-packages
NODE_PATH="$NPM_PACKAGES/lib/node_modules:$NODE_PATH"
export N_PREFIX=$HOME/.n
export PATH="$N_PREFIX/bin:$NPM_PACKAGES/bin:$PATH"

# Configure Python HTTPS requests
export REQUESTS_CA_BUNDLE=$HOME/curl-ca-bundle.crt

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Source local secrets (API keys, tokens, etc.)
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# Initialize Starship prompt
eval "$(starship init zsh)"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"

# --- conductor: per-workspace Storybook (added by Claude) ---
# Launch Storybook on a stable port derived from the Conductor workspace name.
# Same workspace -> same port every time; auto-bumps if the port is busy.
# Usage: sb          (auto port)   |   sb 6200   (force a port)
sb() {
  local root web name port
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in a git repo"; return 1; }
  web="$root/web"; name="$(basename "$root")"
  [ -d "$web" ] || { echo "no web/ dir at $web"; return 1; }
  if [ -n "$1" ]; then
    port="$1"                       # explicit arg wins
  elif [ -n "$CONDUCTOR_PORT" ]; then
    port="$CONDUCTOR_PORT"          # match Conductor's Run button when present
  else
    port=$(( 6010 + $(printf '%s' "$name" | cksum | cut -d' ' -f1) % 80 ))
    while lsof -ti tcp:$port >/dev/null 2>&1; do port=$((port+1)); done
  fi
  echo "▶ Storybook [$name] → http://localhost:$port"
  ( cd "$web" && bunx storybook dev -p "$port" --ci --quiet )
}
# --- end conductor Storybook ---
