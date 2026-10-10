# =============================================================================
# ENVIRONMENT & PATH
# =============================================================================
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# =============================================================================
# HISTORY
# =============================================================================
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS

# =============================================================================
# KEYBINDINGS
# =============================================================================
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# =============================================================================
# PROMPT & VCS
# =============================================================================
autoload -Uz vcs_info
precmd() { vcs_info }

zstyle ':vcs_info:git:*' formats '  %b'
setopt PROMPT_SUBST

git_branch_color() {
    [[ -z ${vcs_info_msg_0_} ]] && return
    if [[ ${vcs_info_msg_0_} == *"main"* ]] || [[ ${vcs_info_msg_0_} == *"master"* ]]; then
        echo "%F{yellow}${vcs_info_msg_0_}%f"
    else
        echo "%F{cyan}${vcs_info_msg_0_}%f"
    fi
}

PROMPT='%F{blue}%n%f %F{yellow}%3~%f $(git_branch_color) %# '

# =============================================================================
# COMPLETIONS & PLUGINS
# =============================================================================
autoload -Uz compinit
compinit

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Bun completions (Ruta dinámica)
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# Debian ZSH plugins (Con validación de existencia)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=246'
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
