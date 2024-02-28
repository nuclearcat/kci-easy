#!/bin/sh
. ./main.cfg

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

# if KCI_CACHE set, git clone linux kernel tree and keep as archive
if [ -n "$KCI_CACHE" ]; then
    if [ ! -f linux.tar ]; then
        git clone --mirror https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux
        tar -cf ../linux.tar linux
        rm -rf linux
    fi
fi

# checkout branches
cd kernelci-core
echo Update core repo
git fetch origin
git checkout $KCI_CORE_BRANCH
cd ..
cd kernelci-api
echo Update api repo
git fetch origin
git checkout $KCI_API_BRANCH
cd ..
cd kernelci-pipeline
echo Update pipeline repo
git fetch origin
git checkout $KCI_PIPELINE_BRANCH
cd ..

# if KCI_CACHE set, unpack linux kernel tree to 
# kernelci/kernelci-pipeline/data/src
if [ -n "$KCI_CACHE" ]; then
    if [ ! -d kernelci-pipeline/data/src/linux ]; then
        tar -xf ../linux.tar -C kernelci-pipeline/data/src
        chown -R 1000:1000 kernelci-pipeline/data/src/linux
    fi
fi

# build docker images
# purge docker build cache with confirmation
echo "Purge docker build cache"
docker builder prune

cd kernelci-api
echo Retrieve API revision and branch
api_rev=$(git show --pretty=format:%H -s origin/$KCI_API_BRANCH)
api_url=$(git remote get-url origin)
cd ..
cd kernelci-core
echo Retrieve Core revision and branch
core_rev=$(git show --pretty=format:%H -s origin/$KCI_CORE_BRANCH)
core_url=$(git remote get-url origin)
build_args="--build-arg core_rev=$core_rev --build-arg api_rev=$api_rev --build-arg core_url=$core_url --build-arg api_url=$api_url"
px_arg='--prefix=kernelci/staging-'
args="build --verbose $px_arg $build_args"
echo Build docker images: kernelci
./kci docker $args kernelci 
echo Build docker images: k8s+kernelci
./kci docker $args k8s kernelci
echo Build docker images: api
./kci docker $args api --version="$api_rev"
echo Tag docker image of api to latest
docker tag kernelci/staging-api:$api_rev kernelci/staging-api:latest
echo Build docker images: clang-17+kselftest+kernelci for x86
./kci docker $args clang-17 kselftest kernelci --arch x86
echo Build docker images: gcc-10+kselftest+kernelci for x86
./kci docker $args gcc-10 kselftest kernelci --arch x86
echo Build docker images: gcc-10+kselftest+kernelci for arm64
./kci docker $args gcc-10 kselftest kernelci --arch arm64



