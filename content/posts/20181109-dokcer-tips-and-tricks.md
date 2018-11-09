+++
title = "Dokcer Tips and Tricks"
date = 2018-11-09T23:47:09+01:00
draft = false
tags = ["docker"]
categories = []
+++

# Remove containers

```
docker ps -a | grep 'hours' | awk '{print $1}' | xargs docker rm
```

You can adapt `'hours'` with `days` or other things to match what you want to delete.


# Remove images

```
docker images --no-trunc | grep none | awk '{print $3}' | xargs docker rmi
```

# Remove orphaned volumes

```
docker volume ls -qf dangling=true | xargs -r docker volume rm
```