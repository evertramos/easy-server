#!/bin/bash

# Clean Everything in Docker Environment
docker system prune --all

# Remove all stopped containers
docker rm -v $(docker ps -a -q)

# Remove all volumes not in use
docker volume rm $(docker volume ls -qf dangling=true)
docker volume ls -qf dangling=true | xargs -r docker volume rm

# Remove all images not in use
docker rmi $(docker images --filter "dangling=true" -q --no-trunc)
docker rmi -f $(docker images | grep "none" | awk '/ / { print $3 }')
#docker rmi -f $(docker images | awk '/ / { print $3 }')

exit 0

