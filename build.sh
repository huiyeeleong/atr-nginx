#!/bin/bash -e
MAJOR_VERSION=1
MINOR_VERSION=1
DOCKER_REGISTRY='aiam-registry.com:443'
IMAGE='aaam/readify-nginx'
SCAN=$3

echo "The Git GIT_BRANCH: $GIT_BRANCH"

if [ -z $BUILD_NUMBER ]; then
  echo "BUILD_NUMBER is absent, set PATCH_VERSION to SNAPSHOT"
  PATCH_VERSION="0-SNAPSHOT"
else
    PATCH_VERSION=$BUILD_NUMBER
fi

# Check for a server
if [ -z "$2" ]; then
  echo "No server environment"
  SERVER_ENV="server"
else
  if [ "$2" == "prod" ]; then
    IFS='.' read -r -a array <<< $GIT_BRANCH
    values=(${array[0]})
    minor=(${array[1]})
    MINOR_VERSION=${array[1]}
    PATCH_VERSION=${array[2]}
    BUILD_VERSION=${MAJOR_VERSION}.${MINOR_VERSION}.${PATCH_VERSION}
    echo "Set version to $BUILD_VERSION"
  else
    SERVER_ENV=$2
    BUILD_VERSION=${MAJOR_VERSION}.${MINOR_VERSION}.${PATCH_VERSION}_${SERVER_ENV}
    echo "Set version to $BUILD_VERSION"
  fi
fi

clean(){
  echo "Clean up"
  if [ "$(docker images -q -f dangling=true)" != '' ];then
    docker rmi -f $(docker images -q -f dangling=true)
  fi
}

package(){
  echo "Packaging container"
  docker build -t ${IMAGE} .
}

push(){
  echo "Tag image version"
  docker tag ${IMAGE} ${DOCKER_REGISTRY}/${IMAGE}:$BUILD_VERSION

  echo "Push image to registry"
  docker push ${DOCKER_REGISTRY}/${IMAGE}:$BUILD_VERSION

  echo "Tag image to latest"
  docker tag ${IMAGE} ${DOCKER_REGISTRY}/${IMAGE}:latest

  echo "Push latest image to registry"
  docker push ${DOCKER_REGISTRY}/${IMAGE}:latest
}

aws-ecr(){
  IMAGE='turing-nginx'
  arr=(${CMD})
  echo "${arr[5]}" | docker login ${arr[6]} -u ${arr[3]} --password-stdin
  
  DOCKER_REGISTRY="${arr[6]:8}"
  echo "${DOCKER_REGISTRY}"
  package
  push

  echo "The variables $1, $2"
  if [ "$1" == "scan" ]; then
    echo "Scanning ECR of $IMAGE and BUILD_VERSION $2"
    python scan_ecr.py uat virginia $IMAGE $2
  fi
  exit 0
}

if [ "$1" == "push-ecr" ]; then
  CMD=$(aws ecr get-login --no-include-email --region us-east-1 --profile non_prod_aws)
  aws-ecr $SCAN $BUILD_VERSION
fi

if [ "$1" == "push-ecr-prod" ]; then
  CMD=$(aws ecr get-login --no-include-email --region us-east-1)
  aws-ecr $SCAN $BUILD_VERSION
fi

package
if [ "$1" == "push" ]; then
  push
fi
