#!/bin/bash

# Clean Everything in Docker Environment
docker system prune --all

# Remove todos os containeres parados
docker rm -v $(docker ps -a -q)

# Remove todos Volumes não utilizados
docker volume rm $(docker volume ls -qf dangling=true)
docker volume ls -qf dangling=true | xargs -r docker volume rm

# Remove todas as imagens não utilizadas
docker rmi $(docker images --filter "dangling=true" -q --no-trunc)
docker rmi -f $(docker images | grep "none" | awk '/ / { print $3 }')

# Todas as images que não estão em uso
docker rmi -f $(docker images | awk '/ / { print $3 }')

#docker volume rm $(docker volume ls -qf dangling=true)

#docker volume ls -qf dangling=true | xargs -r docker volume rm

exit 0
