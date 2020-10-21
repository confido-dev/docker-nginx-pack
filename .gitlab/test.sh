for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"
  DOCKER_NAME="${DOCKER_TEMP}-${DOCKER_VERS}"

  echo "Testing ${DOCKER_VERS}"

  docker run --name $DOCKER_NAME -d $DOCKER_TEMP:$DOCKER_VERS $

  sleep 6

  docker exec $DOCKER_NAME /bin/bash /health.sh

  DOCKER_CODE=$?

  docker stop $DOCKER_NAME
  docker rm $DOCKER_NAME

  if test $DOCKER_CODE -ne 0; then
    echo " - failed"
    exit 1
  fi

  echo " - success"

done

exit 0
