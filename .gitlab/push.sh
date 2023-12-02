docker buildx create --name multiarch_build --use

for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"

  echo "Building final multiarch images for ${DOCKER_VERS}:"

  if [ "${DOCKER_VERS}" = "core" ]; then
    docker buildx build --platform $DOCKER_ARCH --no-cache --tag $DOCKER_BASE:$DOCKER_VERS --build-arg NOT_DUMMY_SSL=true --push .
  else
    docker buildx build --platform $DOCKER_ARCH --tag $DOCKER_BASE:php$DOCKER_VERS --build-arg PHP_VERSION=$DOCKER_VERS --build-arg NOT_DUMMY_SSL=true --push .
  fi

done

exit 0
