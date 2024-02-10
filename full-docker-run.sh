#!/usr/bin/env bash
network_name=net
container_registry=cr.yandex/crpkpigtu17jb8lm8613
envfile=./.env.production
logs_dir=./run.log
errors_dir=./run.errors.log

declare -A flags=(
  ["mongo"]="-p 27017:27017 -v $HOME/db:/data/db"
  ["backend"]="-p 8080:8080 --env-file $envfile" 
  ["nginx"]="-p 80:80 --env-file $envfile" 
)

rm -rf $logs_dir
rm -rf $errors_dir
touch $logs_dir
touch $errors_dir

for index in "${!flags[@]}"; do
  flag="${flags[$index]}"
  
  echo -e "\033[32m[RUN] name:\033[0m $index\033[32m flag:\033[0m $flag"
  
  echo "[RUN] name: $index, flag: $flag" >> $logs_dir
  echo "[RUN] name: $index, flag: $flag" >> $errors_dir
  
  docker pull $container_registry/$index:latest 1>> $logs_dir 2>> $errors_dir
  echo -e "\033[32m[RUN] --Image pulled--\033[0m"
  docker run --name $index -d $flag $container_registry/$index:latest 1>> $logs_dir 2>> $errors_dir
  echo -e "\033[32m[RUN] --Container ran--\033[0m"
  docker network connect --alias $index $network_name $index 1>> $logs_dir 2>> $errors_dir
  echo -e "\033[32m[RUN] --Container connected to network--\033[0m"
  docker restart $index 1>> $logs_dir 2>> $errors_dir
  echo -e "\033[32m[RUN] --Container restarted--\033[0m"
done
