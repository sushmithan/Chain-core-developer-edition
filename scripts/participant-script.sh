#scrip will run on all the participant machines
#!/bin/bash

# install prerequisites 
apt-get update && apt-get install -y libssl-dev libffi-dev python-dev build-essential && apt-get install -y nodejs-legacy && apt-get install -y npm

echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
sudo apt-get install apt-transport-https
sudo apt-get update && sudo apt-get install azure-cli
sudo apt-get update && sudo apt-get install azure-cli

generatornodeip=$1
serviceprincipal=$2
secretkey=$3
tenatid=$4
subscriptionid=$5
keyvaultname=$6
participantclienttokenkeyname=$7
 
az login --service-principal -u $serviceprincipal -p $secretkey --tenant $tenatid
az account set -s $subscriptionid
networkToken="networkTokenSignerVM"

generatornetworktoken=`az keyvault secret show --name $networkToken --vault-name $keyvaultname | grep "value" | cut -d "\"" -f4`
blockchainid=`az keyvault secret show --name blockchainid --vault-name $keyvaultname | grep "value" | cut -d "\"" -f4`

# run chaincore docker image
docker run -d -p 1999:1999 chaincore/developer:ivy-latest
sleep 30
containerId=`docker ps | cut -d " " -f1 | sed 1d`

#participant client access token / public key
docker exec -itd $containerId /usr/bin/chain/cored

partctoken=`docker logs $containerId | grep "^client:" | uniq`

#participant config
response=`docker exec $containerId /usr/bin/chain/corectl config -t $generatornetworktoken  $blockchainid http://$generatornodeip:1999`

docker restart $containerId

az keyvault secret set --name $participantclienttokenkeyname --vault-name $keyvaultname --value $partctoken
