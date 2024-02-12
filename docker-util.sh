#!/bin/bash

### Global variables ###

base_dir=$(pwd)
base_logs_dir=${base_dir}/logs

network_name=net
container_registry=cr.yandex/crpkpigtu17jb8lm8613

### Functions ###

function check_docker_permissions {
  if [ "$(id -u)" -eq 0 ]; then
    return
  fi
    
  if id -nG | grep -qw docker; then
    return
  fi

  echo -e "\033[31m[UTIL]           --Docker permissions not ok--\033[0m"
  echo -e "\033[31m[UTIL]           --Please add yourself to docker group or run script as root--\033[0m"
  help
}

function clear_logs {
  if [ ! -d $base_logs_dir ]; then
    mkdir $base_logs_dir
  fi
  
  logs_dir=${base_logs_dir}/${1}.log
  errors_dir=${base_logs_dir}/${1}.errors.log

  rm -rf $logs_dir
  rm -rf $errors_dir
  touch $logs_dir
  touch $errors_dir
}

function loading {
  local loading_animation=( '—' "\\" '|' '/' )
  local load_interval="${1}"
  local elapsed=0
  
  while [ "${load_interval}" -ne "${elapsed}" ]; do
      for frame in "${loading_animation[@]}" ; do
          printf "\033[32m%s\033[0m\b" "${frame}"
          sleep 0.25
      done
      elapsed=$(( elapsed + 1 ))
  done
  printf " \b\n"
}

function pull_env {
  declare -A env_directories=(
    ["backend"]="./backend"
    ["testbot"]="./testbot"
  )

  clear_logs env

  for index in "${!env_directories[@]}"; do
    cd ${env_directories[$index]}
    rm -rf auth.log
    touch auth.log
    npx dotenv-vault@latest pull production <<< "y" 1>> auth.log 2>> $errors_dir &
    echo -en "\033[32m[PULL ENV]       --Wait-- for:\033[0m $index "
    loading 5
    echo -e "\033[32m[PULL ENV]       --Dotenv vault authentication-- for:\033[0m $index\033[32m url:\033[0m $(grep "Login URL" auth.log | cut -c 22-)"
    echo -e "\033[33m[PULL ENV]       --Press ENTER to continue--\033[0m"
    read 
    echo -en "\033[1F"
    echo -e "\033[32m[PULL ENV]       --Env file loaded-- for:\033[0m $index"
    cd $base_dir
  done
}

function create_network {
  clear_logs network
  
  docker network create $network_name 1>> $logs_dir 2>> $errors_dir
  echo -e "\033[32m[CREATE NETWORK] --Network created-- network-name:\033[0m $network_name"
}

function run_container_and_connect_to_network {
  local name="${1}"
  local flag="${2}"
  local env_file="${3}"

  if [ "${env_file}" != "null" ]; then
    flag="${flag} --env-file ${env_file}"
  fi

  echo -e "\033[32m[RUN]            --Pullind and running container-- name:\033[0m $index\033[32m flag:\033[0m $flag"
  
  echo "[RUN]            name: $index, flag: $flag" >> $logs_dir
  echo "[RUN]            name: $index, flag: $flag" >> $errors_dir
  
  docker pull $container_registry/$name:latest 1>> $logs_dir 2>> $errors_dir
  echo -e "\033[32m[RUN]            --Image pulled-- name:\033[0m $name"
  docker run --name ${name} -d ${flag} $container_registry/${name}:latest 1>> $logs_dir 2>> $errors_dir
  echo -e "\033[32m[RUN]            --Container ran-- name:\033[0m $name"
  docker network connect $network_name ${name} 1>> $logs_dir 2>> $errors_dir
  echo -e "\033[32m[NETWORK]        --Container connected to network-- name:\033[0m $name"
}

function run_containers {
  declare -A flags=(
    ["mongo"]="-p 27017:27017 -v ./db:/data/db"
    ["backend"]="-p 8080:8080" 
    ["nginx"]="-p 80:80" 
    ["testbot"]=""
  )

  declare -A env_files=(
    ["backend"]="${base_dir}/backend/.env.production"
    ["nginx"]="${base_dir}/backend/.env.production"
    ["testbot"]="${base_dir}/testbot/.env.production"
    ["mongo"]="null"
  )
  
  clear_logs containers
  
  for index in "${!flags[@]}"; do
    run_container_and_connect_to_network $index "${flags[$index]}" ${env_files[$index]}
  done

  for index in "${!flags[@]}"; do
    docker restart ${index} 1>> $logs_dir 2>> $errors_dir
    echo -e "\033[32m[RUN]            --Container restarted-- name:\033[0m $index"
  done
}

function remove_containers {
  clear_logs remove
  
  for index in $(docker ps -a -q); do
    docker stop $index 1>> $logs_dir 2>> $errors_dir 
    echo -e "\033[32m[REMOVE]         --Container stopped-- id:\033[0m $index"
    docker rm $index 1>> $logs_dir 2>> $errors_dir
    echo -e "\033[32m[REMOVE]         --Container removed-- id:\033[0m $index"
  done
}

function start_containers {
  clear_logs start
  
  for index in $(docker ps -a -q); do
    docker start $index 1>> $logs_dir 2>> $errors_dir
    echo -e "\033[32m[START]          --Container started-- id:\033[0m $index"
  done
}

function deploy {
  clear_logs deploy
  
  for index in $( echo $1 | tr "," " "); do
    echo $index
    read name path <<< $( echo $index | tr "=" " " )
    
    echo -e "\033[32m[DEPLOY]         --Building image-- name:\033[0m $name\033[32m path:\033[0m $path"
    docker build -t $container_registry/$name:latest $path 1>> $logs_dir 2>> $errors_dir
    echo -e "\033[32m[DEPLOY]         --Pushing image-- name:\033[0m $name"
    docker push $container_registry/$name:latest 1>> $logs_dir 2>> $errors_dir
  done
}

function help {
  echo -e ""
  echo -e "\033[32mUsage:\033[0m $0 \033[33m[-e] [-n] [-r] [-c] [-s] [-d] [-h]\033[0m"
  echo -e "\033[32mOr:\033[0m $0 \033[33m-[e][n][r][c][s][d]\033[0m"
  echo -e ""
  echo -e "\033[32mOptions:\033[0m"
  echo -e "  \033[33m-e\033[0m: Pull env file"
  echo -e "  \033[33m-n\033[0m: Create network"
  echo -e "  \033[33m-r\033[0m: Pull and run containers"
  echo -e "  \033[33m-c\033[0m: Remove containers"
  echo -e "  \033[33m-s\033[0m: Start containers"
  echo -e "  \033[33m-d\033[0m: Deploy containers"
  echo -e "  \033[33m-h\033[0m: Help (this option will exit the script, do not use it with any other options)"
  echo -e ""
  echo -e "\033[32mExample:\033[0m"
  echo -e "  \033[33mRun from the scratch:\033[0m"
  echo -e "    $0 -enr"
  echo -e "  \033[33mStart existing containers:\033[0m"
  echo -e "    $0 -s"
  echo -e "  \033[33mUpdate containers:\033[0m"
  echo -e "    $0 -cer"
  echo -e ""
  echo -e "Created by \033[32mVaf\033[0m"
  echo -e "\033[32mRemember:\033[0m \033[31morder matters!\033[0m"
  echo -e ""
  exit
}

### Script start here ###

tput civis
trap "tput cnorm" EXIT

check_docker_permissions

if [ $# -eq 0 ]; then
  help
fi

while getopts ":henrcsd:" opt; do
  case $opt in
    h)
      echo -e "\033[32m[UTIL]           --\"H\" flag passed--\033[0m"
      help
      ;;
    e)
      echo -e "\033[32m[UTIL]           --\"E\" flag passed--\033[0m"
      pull_env
      ;;
    n)
      echo -e "\033[32m[UTIL]           --\"N\" flag passed--\033[0m"
      create_network
      ;;
    r)
      echo -e "\033[32m[UTIL]           --\"R\" flag passed--\033[0m"
      run_containers
      ;;
    c)
      echo -e "\033[32m[UTIL]           --\"C\" flag passed--\033[0m"
      remove_containers
      ;;
    s)
      echo -e "\033[32m[UTIL]           --\"S\" flag passed--\033[0m"
      start_containers
      ;;
    d)
      echo -e "\033[32m[UTIL]           --\"D\" flag passed--\033[0m"
      deploy $OPTARG
      ;;
    \?)
      echo -e "\033[31m[UTIL]           --Invalid option-- option:\033[0m $OPTARG\n" 
      help
      ;;
  esac
done
