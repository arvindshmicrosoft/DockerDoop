#!/bin/bash


if [[ -z $4 ]]; then
  echo "Usage: $0 <ambariVersion> <node name> <ambariServerHostName> <clusterName>  [<externalIP>]"
  exit -1
fi

ambariVersion="$1"
nodeName="$2"
ambariServerHostName="$3"
clusterName="$4"

portParams=""

if [[ -n $5 ]]; then
    externalIP="$5"

    ports=(22 2181 3000 3372 3373 4040 6080 6627 6667 6700 6701 6702 6703 8000 8010 8020 8025 8030 8032 8050 8080 8081 8088 8141 8443 8744 8886 8983 9000 9080 9081 9082 9083 9084 9085 9086 9087 9090 9999 9933 9995 10000 10020 11000 16010 18080 19888 21000 45454 50010 50020 50060 50070 50075 50090 50111 61080 6667)
    for i in ${ports[@]}; do
        portParams="$portParams -p $externalIP:$i:$i"
    done
fi

docker network ls | grep dockerdoop
if [ $? -ne 0 ]; then
    docker network create dockerdoop
    echo "Created network for DockerDoop"
fi

containerName="$nodeName.$clusterName"

if [ $containerName != $ambariServerHostName ]; then
    echo "Creating Ambari agent node: $nodeName. Ambari server: $ambariServerHostName"

    docker run --privileged \
                --stop-signal=SIGRTMIN+3 \
                -d \
                --dns 8.8.8.8 \
                $portParams \
                -e AMBARI_SERVER=$ambariServerHostName \
                --name $containerName \
                -h $containerName \
                --net dockerdoop \
                --dns-search=$clusterName \
                --restart unless-stopped \
                -i \
                -t 'dockerdoop/ambari_agent_node_'$ambariVersion

    docker exec -i -t $containerName /root/startup.sh
else
    echo "Creating Ambari server node: $nodeName"

    docker run --privileged \
                --stop-signal=RTMIN+3 \
                -d \
                --dns 8.8.8.8 \
                $portParams \
                -e AMBARI_SERVER=$ambariServerHostName \
                --name $containerName \
                -h $containerName \
                --net dockerdoop \
                --dns-search=$clusterName \
                --restart unless-stopped \
                -i \
                -t 'dockerdoop/ambari_server_node_'$ambariVersion

    echo "Setting up Ambari"
    docker exec -i -t $containerName /root/startup.sh
fi

internalIP=$(docker inspect --format "{{ .NetworkSettings.Networks.dockerdoop.IPAddress }}" $containerName)


if [[ -n $4 ]]; then
    echo "$nodeName started. Internal IP = $internalIP, External IP = $5, Cluster = $clusterName"
else
    echo "$nodeName started. Internal IP = $internalIP, Cluster = $clusterName"
fi
