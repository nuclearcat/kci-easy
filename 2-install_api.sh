#!/bin/sh
. ./main.cfg
cp .env-api kernelci/kernelci-api/.env
cp api-configs.yaml kernelci/kernelci-core/config/core/
cp kernelci-cli.toml kernelci/kernelci-core/

cd kernelci/kernelci-api
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
