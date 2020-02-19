# ---------------------------------------------------------------------
#
# Basic Aliases
# 
# ---------------------------------------------------------------------

# Bash Aliases
alias l='ls -la'
alias df='df -h'
alias apt-get='sudo apt-get'

# Git Aliases
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -m'
alias gp='git push'
alias gpp='git pull'
alias gb='git branch'
alias gk='git checkout'

# Laravel
alias a='php artisan'

# Docker
alias d='docker'
alias dl='docker ps'
alias dla='docker ps -a'
alias dr='docker run'
alias de='docker exec'
alias di='docker images'
alias dv='docker volume'
alias dn='docker network'
alias dln='docker network ls'
alias din='docker network inspect'
alias dlo='docker logs'

# Docker Swarm
alias dnode='docker node'
alias dlnode='docker node ls'
alias ddserv='docker service'
alias dlserv='docker service ls'

# Docker Compose
alias dc='docker-compose'
alias dcu='docker-compose up -d'
alias dcd='docker-compose down'
alias dcdv='docker-compose down --volume'

# Docker-Composer wp-cli
alias wp="docker-compose run --rm wpcli"

# Composer Aliases
if [ -d "$HOME/.composer/vendor/bin" ] ; then
    PATH="$HOME/.composer/vendor/bin:$PATH"
fi

# Kubernetes basics
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kga='kubectl get pods --all-namespaces'
alias kgs='kubectl get service'
alias kgn='kubectl get nodes'
alias kgd='kubectl get deployments'
alias kgss='kubectl get secrets'

# Kubernetes config
alias kgc='kubectl config get-contexts'
alias ksc='kubectl config set-context'
alias kuc='kubectl config use-context'
alias kdc='kubectl config delete-context'

# Kubernetes actions
alias kaf='kubectl apply -f'
alias kep='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[0].metadata.name}") -- bash'
alias klc='kubectl logs -f $(kubectl get pod -o jsonpath="{.items[0].metadata.name}") -- eagendas-h-php'

# Other Aliases
# alias gg='cd /your/work/directory'  # WORKDIR
