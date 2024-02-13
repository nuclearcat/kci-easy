#!/bin/sh
KCI_CORE_REPO=https://github.com/kernelci/kernelci-core
KCI_CORE_BRANCH=staging.kernelci.org
KCI_API_REPO=https://github.com/kernelci/kernelci-api
KCI_API_BRANCH=staging.kernelci.org
KCI_PIPELINE_REPO=https://github.com/kernelci/kernelci-pipeline
KCI_PIPELINE_BRANCH=staging.kernelci.org

# if directry kernelci doesn't exist, then we dont have repos cloned
if [ ! -d kernelci ]; then
    mkdir kernelci
    cd kernelci
    git clone $KCI_CORE_REPO
    git clone $KCI_API_REPO
    git clone $KCI_PIPELINE_REPO
else
    cd kernelci
    cd kernelci-core
    git pull
    cd ..
    cd kernelci-api
    git pull
    cd ..
    cd kernelci-pipeline
    git pull
    cd ..
fi

# checkout branches
cd kernelci-core
git fetch origin
git checkout $KCI_CORE_BRANCH
cd ..
cd kernelci-api
git fetch origin
git checkout $KCI_API_BRANCH
cd ..
cd kernelci-pipeline
git fetch origin
git checkout $KCI_PIPELINE_BRANCH
cd ..

# build docker images
# purge docker build cache with confirmation
docker builder prune

cd kernelci-api
api_rev=$(git show --pretty=format:%H -s origin/$KCI_API_BRANCH)
api_url=$(git remote get-url origin)
cd ..
cd kernelci-core
core_rev=$(git show --pretty=format:%H -s origin/staging.kernelci.org)
core_url=$(git remote get-url origin)
build_args="--build-arg core_rev=$core_rev --build-arg api_rev=$api_rev --build-arg core_url=$core_url --build-arg api_url=$api_url"
px_arg='--prefix=kernelci/staging-'
args="build $px_arg $build_args"
./kci docker $args kernelci 
./kci docker $args k8s kernelci
./kci docker $args api --version="$api_rev"
docker tag kernelci/staging-api:$api_rev kernelci/staging-api:latest
./kci docker $args clang-17 kselftest kernelci --arch x86
./kci docker $args gcc-10 kselftest kernelci --arch x86



