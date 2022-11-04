# Docker-Compose 部署fisco和webase

## 1.搭建区块链网络
```bash
docker network create -d bridge --subnet=172.26.0.0/16 --gateway=172.26.0.1 fisco_network
```

## 2.新建节点
```bash
#!/bin/bash
fisco_dir=./output/fisco
webase_dir=./output/webase

#仅限单机运行
[fisco]
#国密
gm=0
output=./nodes
nodes=server1 server2 server3 server4

[server1]
ip=172.25.0.2
num=1
agencyName=agency
groups=1,2
ports=30300,20200,8545

[server2]
ip=172.25.0.3
num=1
agencyName=agency
groups=1,2,3
ports=30300,20200,8545

[server3]
ip=172.25.0.4
num=1
agencyName=agency
groups=1,3
ports=30300,20200,8545

[server4]
ip=172.25.0.5
num=1
agencyName=agency
groups=2,3
ports=30300,20200,8545
```