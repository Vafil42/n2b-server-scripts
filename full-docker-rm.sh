#!/usr/bin/env bash

for index in $(docker ps -a -q); do
  docker stop $index >> /dev/null
  echo -e "\033[32m[STOP] --Container stopped-- id:\033[0m $index"
  docker rm $index >> /dev/null
  echo -e "\033[32m[STOP] --Container removed-- id:\033[0m $index"
done

