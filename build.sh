#!/bin/bash

# Copyright 2022-2023, 信医科技.
set -e

function print_banner {
    echo '             __               '
    echo '|/    |_  _ (_  o __ __  _  _|'
    echo '|\ |_||_)(/___) | ||||||(/_(_|'
}

function is_linux {
	if [[ $(uname -s) == Linux ]]; then
		true
	else
		false
	fi
}

function is_mac {
	if [[ $(uname -s) == Darwin ]]; then
		true
	else
		false
	fi
}

function ReadINIfile() {
    Key=$1
    Section=$2
    Configfile=$3
    ReadINI=`awk -F '=' '/\['$Section'\]/{a=1}a==1&&$1~/'$Key'/{print $2;exit}' $Configfile`
    echo "$ReadINI"
}


function load_config {
    BASEDIR=$(dirname "$0")
    cd $BASEDIR
    WORKINGDIR=$(pwd)
    configFile="${WORKINGDIR}/config.ini"
    gm=`ReadINIfile "gm" "fisco" "$configFile"`
    nodes=(`ReadINIfile "nodes" "fisco" "$configFile"`)
    output=(`ReadINIfile "output" "fisco" "$configFile"`)
    echo ""
    echo "Loaded Build Config"
    echo "fisco:"
    echo "  gm: ${gm}"
    echo "  output: ${output}"
    echo "nodes:"
    for ((i = 0; i < ${#nodes[*]}; i++)); do
        server_name=${nodes[${i}]}
        echo "  ${server_name}:"
        ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
        echo "  ip: ${ip}"
        num=(`ReadINIfile "num" "$server_name" "$configFile"`)
        echo "  num: ${num}"
        agencyName=(`ReadINIfile "agencyName" "$server_name" "$configFile"`)
        echo "  agencyName: ${agencyName}"
        groups=(`ReadINIfile "groups" "$server_name" "$configFile"`)
        echo "  groups: ${groups}"
        ports=(`ReadINIfile "ports" "$server_name" "$configFile"`)
        echo "  ports: ${ports}"
        echo " "
    done

  cat >nodes.conf <<EOF
$(for ((j = 0; j < ${#nodes[*]}; j++)); do
server_name=${nodes[${j}]}
ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
num=(`ReadINIfile "num" "$server_name" "$configFile"`)
agencyName=(`ReadINIfile "agencyName" "$server_name" "$configFile"`)
groups=(`ReadINIfile "groups" "$server_name" "$configFile"`)
ports=(`ReadINIfile "ports" "$server_name" "$configFile"`)
echo "${ip}:${num} ${agencyName} ${groups} ${ports}"
done)
EOF
if [ -d ${output} ]; then
	# rm -rf ${output}
    # docker-compose down
    index=0
    for ((i = 0; i < ${#nodes[*]}; i++)); do
        server_name=${nodes[${i}]}
        ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
        agencyName=(`ReadINIfile "agencyName" "$server_name" "$configFile"`)
        num=(`ReadINIfile "num" "$server_name" "$configFile"`)
        echo "${output}/${ip}"
        if [ -d ${output}/${ip} ]; then
            index=$i
            for((k=0;k<$num;k++));
            do
                if [ -d ${output}/${ip}/node${k} ]; then
                    echo "已存在${ip}/node${k}"
                fi
            done
        else
            echo "新增节点${ip}"
            has_server=${nodes[${index}]}
            has_ip=(`ReadINIfile "ip" "$has_server" "$configFile"`)
            cp ${output}/cert/${agencyName}/cert.cnf  ${output}/cert/${agencyName}/channel/
            bash gen_node_cert.sh -c ${output}/cert/agency -o ${output}/${ip}/node0
            cp -r ${output}/${has_ip}/sdk ${output}/${ip}/sdk
            cp ${output}/${has_ip}/fisco-bcos ${output}/${ip}/fisco-bcos
            cp ${output}/${has_ip}/*.sh ${output}/${ip}/
            cp ${output}/${has_ip}/node0/config.ini ${output}/${ip}/node0/config.ini
            cp ${output}/${has_ip}/node0/conf/group.1.genesis ${output}/${ip}/node0/conf/group.1.genesis
            cp ${output}/${has_ip}/node0/conf/group.1.ini ${output}/${ip}/node0/conf/group.1.ini
            cp ${output}/${has_ip}/node0/*.sh ${output}/${ip}/node0/
            cp -r ${output}/${has_ip}/node0/scripts ${output}/${ip}/node0/
            group_row_num=$(grep -n "state"  ${output}/${ip}/node0/conf/group.1.genesis | head -1 | cut -d ":" -f 1)
            echo "${group_row_num}"
            group_insert_row=`expr $group_row_num - 1`
            conf_row_num=$(grep -n "certificate_blacklist"  ${output}/${ip}/node0/config.ini | head -1 | cut -d ":" -f 1)
            echo "${conf_row_num}"
            conf_insert_row=`expr $conf_row_num - 2`
            echo "${conf_insert_row}"
            group_nodeid="node.${i}=$(cat ${output}/${ip}/node0/conf/node.nodeid)"
            echo "${group_nodeid}"
            conf_nodeid="node.${i}=${ip}:30300"
            echo "${conf_nodeid}"
            for file in ${output}/*
            do
                if test -f $file; then
                    echo "$file"
                else
                    if [ -d ${file}/node0 ]; then
                        echo "$file"
                        if is_mac; then
                            sed -i "" "${group_insert_row} i\\                                
    ${group_nodeid}
    "  ${file}/node0/conf/group.1.genesis
                            sed -i "" "${conf_insert_row} i\\                                
    ${conf_nodeid}
    "  ${file}/node0/config.ini
                        else
                            sed -i "${group_insert_row} i\\    ${group_nodeid}"  ${file}/node0/conf/group.1.genesis
                            sed -i "${conf_insert_row} i\\    ${conf_nodeid}"  ${file}/node0/config.ini
                        fi
                    fi
                fi
            done
        fi
    done
else
    if is_mac; then
        bash build_chain.sh -e bin/mac/fisco-bcos -f nodes.conf -T -o ${output}
    else
         bash build_chain.sh -e bin/linux/fisco-bcos -f nodes.conf -T -o ${output}
    fi
    rm -rf nodes.conf
fi
echo "生成docker-compose"
for file in ${output}/*
do
    if test -f $file; then
        echo ""
    else
        if [ -d ${file}/node0 ]; then
            cat >${file}/docker-compose.yml <<EOF
version : '3'
services:

  chain-node0:
    image: fiscoorg/fiscobcos:v2.9.0
    container_name: chain-node0
    working_dir: /data
    command: -c  config.ini
    volumes:
      - ./node0/:/data/
    ports:
      - "30300:30300"
      - "8545:8545"
      - "20200:20200"
    networks:
      - web_network

networks:
  web_network:
    external: true
EOF
        fi
    fi
done


}

function show_usage {
    echo ""
    echo "Usage: ./one_build.sh"
}

main() {
    print_banner
    load_config

	exit 0
}

main $@
