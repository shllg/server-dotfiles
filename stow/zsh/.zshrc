# -- Oh My Zsh -----------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# -- Environment ---------------------------------------------------------------
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export EDITOR='vim'
export LANG=en_US.UTF-8

# -- History tuning ------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

# -- Directory navigation -----------------------------------------------------
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus

# -- Completion ----------------------------------------------------------------
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# -- Aliases -------------------------------------------------------------------
alias ll='ls -lAh'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ..='cd ..'
alias ...='cd ../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias gds='git diff --staged'

# -- Functions -----------------------------------------------------------------
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# -- Server-specific overrides (not managed by stow) --------------------------
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
