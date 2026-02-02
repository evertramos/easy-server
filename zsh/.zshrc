# Safe history
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# No glob expand
setopt NO_NOMATCH

# prompt 
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f ${vcs_info_msg_0_}%(!.#.$) '

[[ -o interactive ]] || return
autoload -U colors && colors
autoload -Uz vcs_info
precmd() { vcs_info }
setopt prompt_subst
#git_prompt_info='${vcs_info_msg_0_}'
zstyle ':vcs_info:git:*' formats '(%F{yellow}%b%f)'
eval "$(dircolors -b)"
alias ls='ls --color=auto'
