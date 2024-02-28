#!/bin/sh
. ./main.cfg

cp .env-api kernelci/kernelci-api/.env
cp api-configs.yaml kernelci/kernelci-core/config/core/
cp kernelci-cli.toml kernelci/kernelci-core/kernelci.toml

cd kernelci/kernelci-api
mkdir -p docker/redis/data
chmod -R 0777 docker/storage/data
chmod -R 0777 docker/redis/data
# enable ssh and storage nginx
sed -i 's/^#  /  /' docker-compose.yaml
if [ -f ../../ssh.key ]; then
    echo "ssh.key already exists"
else
    # generate non-interactively ssh key to ssh.key
    ssh-keygen -t rsa -b 4096 -N "" -f ../../ssh.key
    # get public key and add to docker/ssh/user-data/authorized_keys
    cat ../../ssh.key.pub >> docker/ssh/user-data/authorized_keys
fi

# down, just in case old containers are running
docker-compose down
docker-compose up -d
echo "Waiting for API to be up"
sleep 1
# loop until the API is up, try 5 times
i=0
while [ $i -lt 5 ]; do
    ANSWER=$(curl http://localhost:8001/latest/)
    # must be {"message":"KernelCI API"}
    if [ "$ANSWER" != "{\"message\":\"KernelCI API\"}" ]; then
        echo "API is not up"
        i=$((i+1))
        sleep 5
    else
        echo "API is up"
        break
    fi
done

# INFO, if you have issues with stale/old data, check for 
# docker volume kernelci-api_mongodata and delete it
./scripts/setup_admin_user --email ${YOUR_EMAIL}

cd ../kernelci-core
echo "Issuing token for admin user"
./kci user token admin > ../../admin-token.txt
ADMIN_TOKEN=$(cat ../../admin-token.txt)

echo "[kci.secrets]
api.\"docker-host\".token = \"$ADMIN_TOKEN\" 
" >> kernelci.toml

