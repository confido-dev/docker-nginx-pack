for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"

  if [ "${DOCKER_VERS}" != "core" ]; then DOCKER_VERS="php${ver}"; fi

  echo "Cleaning cache for ${DOCKER_VERS}"

  docker rmi $DOCKER_TEMP:$DOCKER_VERS

done

exit 0
