for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"

  echo "Pushing ${DOCKER_VERS}"

  docker tag $DOCKER_TEMP:$DOCKER_VERS $DOCKER_BASE:$DOCKER_VERS && docker push $DOCKER_BASE:$DOCKER_VERS

done

exit 0
