#!/usr/bin/env bash

errors_dir=./init.errors.log
logs_dir=./init.log
rm -rf $logs_dir
rm -rf $errors_dir
touch $errors_dir
touch $logs_dir

network_name=net

npx dotenv-vault@latest pull production < "y.txt" 1>> $logs_dir 2>> $errors_dir &
sleep 5
echo -e "\033[32m[INIT] --Dotenv vault authentication-- url:\033[0m $(grep "Login URL" $logs_dir | cut -c 22-)"
read -p "Press any key to continue..."
echo -e "\033[32m[INIT] --Env file loaded--\033[0m"

docker network create $network_name 1>> $logs_dir 2>> $errors_dir
echo -e "\033[32m[INIT] --Network created-- network-name:\033[0m $network_name"

