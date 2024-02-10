#!/usr/bin/env bash

for index in $(docker ps -a -q); do
  docker start $index >> /dev/null
  echo -e "\033[32m[START] --Container started-- id:\033[0m $index"
done
