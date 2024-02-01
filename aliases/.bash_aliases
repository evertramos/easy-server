#---------------------------------------------------------------------
#
# Basic Aliases
# 
#---------------------------------------------------------------------

# Bash Aliases
alias l='ls -la'
alias df='df -h'
alias apt-get='sudo apt-get'
alias apt='sudo apt-get'

# Python
alias p='python3.8'
alias p3='python3'
alias p2='python2'

# Git Aliases
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -m'
alias gp='git push'
alias gpp='git pull'
alias gpps='git pull --recurse-submodules'
alias gb='git branch'
alias gk='git checkout'
alias gmd='git checkout main && git merge --no-edit dev && git push --force && git checkout dev'

# Laravel
alias a='php artisan'

# Docker
alias d='docker'
alias dl='docker ps'
alias sdl='docker ps --format "table {{.Image}}\t{{.Status}}\t{{.Names}}"'
alias pdl='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dla='docker ps -a'
alias dr='docker run'
alias de='docker exec'
alias di='docker images'
alias dv='docker volume'
alias dlv='docker volume ls'
alias dn='docker network'
alias dln='docker network ls'
alias din='docker network inspect'
alias dlo='docker logs'
alias dlf='docker logs -f --tail 50'

# Docker Swarm
alias dnode='docker node'
alias dlnode='docker node ls'
alias ddserv='docker service'
alias dlserv='docker service ls'

# Docker Compose
alias docker-compose='docker compose'
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
alias kep2='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[1].metadata.name}") -- bash'
alias kep3='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[2].metadata.name}") -- bash'
alias kep4='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[3].metadata.name}") -- bash'
alias kep5='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[4].metadata.name}") -- bash'
alias kep6='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[5].metadata.name}") -- bash'
alias kep7='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[6].metadata.name}") -- bash'
alias kep8='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[7].metadata.name}") -- bash'
alias kep9='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[8].metadata.name}") -- bash'
alias kep10='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[9].metadata.name}") -- bash'

alias kepp='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[0].metadata.name}") --container eagendas-p-nginx -- bash'
alias kepp2='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[1].metadata.name}") --container eagendas-p-nginx -- bash'
alias kepp3='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[2].metadata.name}") --container eagendas-p-nginx -- bash'
alias kepp4='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[3].metadata.name}") --container eagendas-p-nginx -- bash'
alias kepp5='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[4].metadata.name}") --container eagendas-p-nginx -- bash'
alias kepp6='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[5].metadata.name}") --container eagendas-p-nginx -- bash'
alias kepp7='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[6].metadata.name}") --container eagendas-p-nginx -- bash'
alias kepp8='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[7].metadata.name}") --container eagendas-p-nginx -- bash'
alias kepp9='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[8].metadata.name}") --container eagendas-p-nginx -- bash'
alias kepp10='kubectl exec -it $(kubectl get pod -o jsonpath="{.items[9].metadata.name}") --container eagendas-p-nginx -- bash'

alias klc='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[0].metadata.name}") -- '
alias klc2='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[1].metadata.name}") -- '
alias klc3='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[2].metadata.name}") -- '
alias klc4='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[3].metadata.name}") -- '
alias klc5='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[4].metadata.name}") -- '
alias klc6='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[5].metadata.name}") -- '
alias klcc='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[0].metadata.name}") -c eagendas-p-nginx -- '
alias klcc1='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[0].metadata.name}") -c $1 -- '
alias klcc2='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[1].metadata.name}") -c eagendas-p-nginx -- '
alias klcc3='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[2].metadata.name}") -c eagendas-p-nginx -- '
alias klcc4='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[3].metadata.name}") -c eagendas-p-nginx -- '
alias klcc5='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[4].metadata.name}") -c eagendas-p-nginx -- '
alias klcc6='kubectl logs -f --tail 100 $(kubectl get pod -o jsonpath="{.items[5].metadata.name}") -c eagendas-p-nginx -- '

# Kubens
alias kb='kubens'

# Kubectx
alias kx='kubectx'

# Flutter basics
alias f='flutter'
alias fc='flutter config'

# Apps
alias tor='cd ~/Downloads/tor && ./start-tor-browser.desktop && cd -'
alias code='code-insiders'

# Other Aliases
ALIAS_HOME_BASE_PATH="~/server"

alias gg='cd $ALIAS_HOME_BASE_PATH'         # Basedir
alias ggs='cd $ALIAS_HOME_BASE_PATH/sites'  # Sites
alias ggb='cd $ALIAS_HOME_BASE_PATH/backup' # Backup
alias ggp='cd $ALIAS_HOME_BASE_PATH/proxy'  # Proxy
alias ggd='cd $ALIAS_HOME_BASE_PATH/dev'    # Development

# Sail
alias sail='bash vendor/bin/sail'

# Rust
alias c='cargo'

# Auth
alias auth='auth --cluster $(kubectx -c | cut -f2 -d"@")'
