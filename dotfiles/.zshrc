
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
