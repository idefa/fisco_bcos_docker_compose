#!/bin/bash

# Copyright 2022-2023, 信医科技.
set -e
exsist_node_num=0
node_groups=
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

function count_nodes() {
    for ((i = 0; i < ${#nodes[*]}; i++)); do
            server_name=${nodes[${i}]}
            ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
            num=(`ReadINIfile "num" "$server_name" "$configFile"`)
            for((k=0;k<$num;k++)); do
                if [ -d ${output}/${ip}/node${k} ]; then
                    exsist_node_num=`expr $exsist_node_num + 1`
                fi
            done
    done
    echo "已有节点数量:${exsist_node_num}"
}

function count_groups(){
    for ((i = 0; i < ${#nodes[*]}; i++)); do
            server_name=${nodes[${i}]}
            ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
            groups=(`ReadINIfile "groups" "$server_name" "$configFile"`)
            for((k=0;k< ${#groups[*]};k++)); do
                group_id=${groups[${k}]}
                node_groups[${group_id}]=${group_id}
            done
    done
    echo "已存在分组:${node_groups[@]}"
}

function gen_groups(){
    for(( j=0;j<${#node_groups[@]};j++)) 
    do
        group_node_num=0
        group_id=${node_groups[j]}
        if [ $group_id -gt 0 ]; then
            rm -rf ${output}/group.${group_id}.ini
            rm -rf ${output}/group.${group_id}.genesis
            cat >${output}/group.${group_id}.ini <<EOF
[consensus]
    ; the ttl for broadcasting pbft message
    ttl=2
    ; min block generation time(ms)
    min_block_generation_time=500
    enable_dynamic_block_size=true
    enable_ttl_optimization=true
    enable_prepare_with_txsHash=true
    ; The following is the relevant configuration of rpbft
    ; set true to enable broadcast prepare request by tree
    broadcast_prepare_by_tree=true
    ; percent of nodes that broadcast prepare status to, must be between 25 and 100
    prepare_status_broadcast_percent=33
    ; max wait time before request missed transactions, ms, must be between 5ms and 1000ms
    max_request_missedTxs_waitTime=100
    ; maximum wait time before requesting a prepare, ms, must be between 10ms and 1000ms
    max_request_prepare_waitTime=100

[storage]
    ; storage db type, rocksdb / mysql / scalable, rocksdb is recommended
    type=rocksdb
    ; set true to turn on binary log
    binary_log=false
    ; scroll_threshold=scroll_threshold_multiple*1000, only for scalable
    scroll_threshold_multiple=2
    ; set fasle to disable CachedStorage
    cached_storage=true
    ; max cache memeory, MB
    max_capacity=32
    max_forward_block=10
    ; only for external, deprecated in v2.3.0
    max_retry=60
    topic=DB
    ; only for mysql
    db_ip=127.0.0.1
    db_port=3306
    db_username=
    db_passwd=
    db_name=
[tx_pool]
    limit=150000
    ; transaction pool memory size limit, MB
    memory_limit=512
    ; number of threads responsible for transaction notification,
    ; default is 2, not recommended for more than 8
    notify_worker_num=2
    ; transaction expiration time, in seconds
    ; default is 10 minute(600s)
    txs_expiration_time=600
[sync]
    ; max memory size used for block sync, must >= 32MB
    max_block_sync_memory_size=512
    idle_wait_ms=200
    ; send block status by tree-topology, only supported when use pbft
    sync_block_by_tree=true
    ; send transaction by tree-topology, only supported when use pbft
    ; recommend to use when deploy many consensus nodes
    send_txs_by_tree=true
    ; must between 1000 to 3000
    ; only enabled when sync_by_tree is true
    gossip_interval_ms=1000
    gossip_peers_number=3
    ; max number of nodes that broadcast txs status to, recommended less than 5
    txs_max_gossip_peers_num=5
[flow_control]
    ; restrict QPS of the group
    ;limit_req=1000
    ; restrict the outgoing bandwidth of the group
    ; Mb, can be a decimal
    ; when the outgoing bandwidth exceeds the limit, the block synchronization operation will not proceed
    ;outgoing_bandwidth_limit=2

[sdk_allowlist]
    ; When sdk_allowlist is empty, all SDKs can connect to this node
    ; when sdk_allowlist is not empty, only the SDK in the allowlist can connect to this node
    ; public_key.0 should be nodeid, nodeid's length is 128
    ;public_key.0=
EOF

            cat >${output}/group.${group_id}.genesis <<EOF
[consensus]
    ; consensus algorithm now support PBFT(consensus_type=pbft), Raft(consensus_type=raft)
    ; rpbft(consensus_type=rpbft)
    consensus_type=pbft
    ; the max number of transactions of a block
    max_trans_num=1000
    ; in seconds, block consensus timeout, at least 3s
    consensus_timeout=3
    ; rpbft related configuration
    ; the working sealers num of each consensus epoch
    epoch_sealer_num=5
    ; the number of generated blocks each epoch
    epoch_block_num=1000
    ; the node id of consensusers
$(for ((p = 0; p < ${#nodes[*]}; p++)); do
        server_name=${nodes[${p}]}
        ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
        groups=(`ReadINIfile "groups" "$server_name" "$configFile"`)
        if [[ " ${groups[*]} " =~ " ${group_id} " ]]; then
            for((q=0;q< $num;q++)); do
if [ -d ${output}/${ip}/node${q} ]; then
nodeid="node.${group_node_num}=$(cat ${output}/${ip}/node${q}/conf/node.nodeid)"
echo "    ${nodeid}"
                        group_node_num=`expr $group_node_num + 1`
fi
            done
        fi
done)
[state]
    type=storage
[tx]
    ; transaction gas limit
    gas_limit=300000000
[group]
    id=${group_id}
    timestamp=1668575944000
[evm]
    enable_free_storage=false
EOF
        fi
    done;

    for ((i = 0; i < ${#nodes[*]}; i++)); do
            server_name=${nodes[${i}]}
            ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
            num=(`ReadINIfile "num" "$server_name" "$configFile"`)
            groups=(`ReadINIfile "groups" "$server_name" "$configFile"`)
            for((k=0;k<$num;k++)); do
                if [ -d ${output}/${ip}/node${k} ]; then
                    for((b=0;b< ${#groups[*]};b++)); do
                        cur_group_id=${groups[${b}]}
                        cp -rf ${output}/group.${cur_group_id}.ini ${output}/${ip}/node${k}/conf/group.${cur_group_id}.ini
                        cp -rf ${output}/group.${cur_group_id}.genesis ${output}/${ip}/node${k}/conf/group.${cur_group_id}.genesis
                    done
                fi
            done
    done
}

function update_config() {
    local group_insert_row="${1}"
    local conf_nodeid="${2}"
    local output="${3}"
    for ((i = 0; i < ${#nodes[*]}; i++)); do
        server_name=${nodes[${i}]}
        ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
        agencyName=(`ReadINIfile "agencyName" "$server_name" "$configFile"`)
        num=(`ReadINIfile "num" "$server_name" "$configFile"`)
        groups=(`ReadINIfile "groups" "$server_name" "$configFile"`)
        for((k=0;k<$num;k++)); do
            if [ -d ${output}/${ip}/node${k} ]; then
                echo "${output}/${ip}/node${k}"
                if is_mac; then
                    sed -i "" "${conf_insert_row} i\\
    ${conf_nodeid}
    "  ${output}/${ip}/node${k}/config.ini
                else
                    sed -i "${conf_insert_row} i\\    ${conf_nodeid}"  ${output}/${ip}/node${k}/config.ini
                fi
            fi
        done
    done
}



function docker_compose(){
    total_num=0
    for ((i = 0; i < ${#nodes[*]}; i++)); do
        server_name=${nodes[${i}]}
        ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
        agencyName=(`ReadINIfile "agencyName" "$server_name" "$configFile"`)
        num=(`ReadINIfile "num" "$server_name" "$configFile"`)
cat >${output}/${ip}/docker-compose.yml <<EOF
version : '3'
services:
$(for ((k=0;k<$num;k++)); do
listen_port=`expr 30300 + ${k}`
jsonrpc_listen_port=`expr 8545 + ${k}`
channel_listen_port=`expr 20200 + ${k}`
if [ ${debug}="1" ]; then
    listen_port=`expr 30300 + ${total_num} + ${k}`
    jsonrpc_listen_port=`expr 8545 + ${total_num} + ${k}`
    channel_listen_port=`expr 20200 + ${total_num} + ${k}`
fi
if [ ${debug}="1" ]; then
nodenum=`expr ${total_num} + ${k}`
echo "  chain-node${nodenum}:"
else
echo "  chain-node${k}:"
fi
echo "    image: fiscoorg/fiscobcos:v2.9.0"
if [ ${debug}="1" ]; then
nodenum=`expr ${total_num} + ${k}`
echo "    container_name: chain-node${nodenum}"
else
echo "    container_name: chain-node${k}"
fi
echo "    working_dir: /data"
echo "    command: -c  config.ini"
echo "    volumes:"
echo "      - ./node${k}:/data"
echo "    ports:"
echo "      - ${listen_port}:30300"
echo "      - ${jsonrpc_listen_port}:8545"
echo "      - ${channel_listen_port}:20200"
echo "    networks:"
        if [ ${debug}="1" ]; then
echo "      web_network:"
echo "        ipv4_address: ${ip}"
        else
echo "      - web_network"
        fi
echo ""
done)
networks:
  web_network:
    external: true
EOF
total_num=`expr ${total_num} + $num`
    done
}


function load_config {
    BASEDIR=$(dirname "$0")
    cd $BASEDIR
    WORKINGDIR=$(pwd)
    configFile="${WORKINGDIR}/config.ini"
    debug=`ReadINIfile "debug" "fisco" "$configFile"`
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

has_server=
has_ip=
if [ -d ${output} ]; then
    count_nodes
    count_groups
	# rm -rf ${output}
    # docker-compose down
    index=0
    for ((i = 0; i < ${#nodes[*]}; i++)); do
        server_name=${nodes[${i}]}
        ip=(`ReadINIfile "ip" "$server_name" "$configFile"`)
        agencyName=(`ReadINIfile "agencyName" "$server_name" "$configFile"`)
        num=(`ReadINIfile "num" "$server_name" "$configFile"`)
        groups=(`ReadINIfile "groups" "$server_name" "$configFile"`)
        echo "--------------${output}/${ip}/${num}"
        if [ -d ${output}/${ip} ]; then
            index=$i
            for((k=0;k<$num;k++)); do
                if [ -d ${output}/${ip}/node${k} ]; then
                    has_server=${nodes[${index}]}
                    has_ip=(`ReadINIfile "ip" "$has_server" "$configFile"`)
                    echo "已存在${ip}/node${k}"
                else
                    echo "新增节点${ip}/node${k}"
                    bash gen_node_cert.sh -c ${output}/cert/agency -o ${output}/${ip}/node${k}
                    cp ${output}/${has_ip}/node0/config.ini ${output}/${ip}/node${k}/config.ini
                    cp ${output}/${has_ip}/node0/conf/group.1.genesis ${output}/${ip}/node${k}/conf/group.1.genesis
                    cp ${output}/${has_ip}/node0/conf/group.1.ini ${output}/${ip}/node${k}/conf/group.1.ini
                    cp ${output}/${has_ip}/node0/*.sh ${output}/${ip}/node${k}/
                    cp -r ${output}/${has_ip}/node0/scripts ${output}/${ip}/node${k}/
                    conf_row_num=$(grep -n "certificate_blacklist"  ${output}/${ip}/node${k}/config.ini | head -1 | cut -d ":" -f 1)
                    echo "${conf_row_num}"
                    conf_insert_row=`expr $conf_row_num - 2`
                    echo "${conf_insert_row}"
                    group_node_port=`expr 30300 + ${k}`
                    conf_nodeid="node.${exsist_node_num}=${ip}:${group_node_port}"
                    echo "${conf_nodeid}"
                    update_config  ${conf_insert_row} ${conf_nodeid} ${output}
                    exsist_node_num=`expr $exsist_node_num + 1`
                fi
            done
        else
            echo "新增节点${ip}"
            echo "has_ip：${has_ip}"
            for((J=0;J<$num;J++)); do
                echo "新增节点${ip}/node${J}"
                bash gen_node_cert.sh -c ${output}/cert/agency -o ${output}/${ip}/node${J}
                cp -r ${output}/${has_ip}/sdk ${output}/${ip}/sdk
                cp ${output}/${has_ip}/fisco-bcos ${output}/${ip}/fisco-bcos
                cp ${output}/${has_ip}/*.sh ${output}/${ip}/
                cp ${output}/${has_ip}/node0/config.ini ${output}/${ip}/node${J}/config.ini
                cp ${output}/${has_ip}/node0/conf/group.1.genesis ${output}/${ip}/node${J}/conf/group.1.genesis
                cp ${output}/${has_ip}/node0/conf/group.1.ini ${output}/${ip}/node${J}/conf/group.1.ini
                cp ${output}/${has_ip}/node0/*.sh ${output}/${ip}/node${J}/
                cp -r ${output}/${has_ip}/node0/scripts ${output}/${ip}/node${J}/
                conf_row_num=$(grep -n "certificate_blacklist"  ${output}/${ip}/node${J}/config.ini | head -1 | cut -d ":" -f 1)
                echo "${conf_row_num}"
                conf_insert_row=`expr $conf_row_num - 2`
                echo "${conf_insert_row}"
                group_node_port=`expr 30300 + ${J}`
                conf_nodeid="node.${exsist_node_num}=${ip}:${group_node_port}"
                echo "${conf_nodeid}"
                update_config  ${conf_insert_row} ${conf_nodeid} ${output}
                exsist_node_num=`expr $exsist_node_num + 1`
            done
        fi
    done
    echo "生成group文件"
    gen_groups
else
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
    if is_mac; then
        bash build_chain.sh -e bin/mac/fisco-bcos -f nodes.conf -T -o ${output}
    else
         bash build_chain.sh -e bin/linux/fisco-bcos -f nodes.conf -T -o ${output}
    fi
    rm -rf nodes.conf
    cp ${output}/cert/${agencyName}/cert.cnf  ${output}/cert/${agencyName}/channel/
fi
echo "生成docker-compose"
docker_compose
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
