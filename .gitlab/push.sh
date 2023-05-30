for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"

  if [ "${DOCKER_VERS}" != "core" ]; then DOCKER_VERS="php${ver}"; fi

  echo "Pushing ${DOCKER_VERS}"

  docker image tag $DOCKER_TEMP:$DOCKER_VERS $DOCKER_BASE:$DOCKER_VERS && docker image push $DOCKER_BASE:$DOCKER_VERS

done

exit 0
