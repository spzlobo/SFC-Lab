#!/bin/bash
set -e
ssh_options='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
BASEDIR=`dirname $0`
INSTALLER_IP=${INSTALLER_IP:-10.20.0.2}

pushd $BASEDIR
ip=$(sshpass -p r00tme ssh $ssh_options root@${INSTALLER_IP} 'fuel node'|grep controller|awk '{print $9}' | head -1)
echo $ip

if [ ${#ip}  -le 6 ]
then
  echo "${ip} not a valid IP address"
  exit 1
fi

sshpass -p r00tme scp $ssh_options delete.sh ${INSTALLER_IP}:/root
sshpass -p r00tme ssh $ssh_options root@${INSTALLER_IP} 'scp '"$ip"':/root/tackerc .'
sshpass -p r00tme scp $ssh_options ${INSTALLER_IP}:/root/tackerc $BASEDIR
