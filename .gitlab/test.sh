for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"
  DOCKER_NAME="${DOCKER_TEMP}-${DOCKER_VERS}"

  if [ "${DOCKER_VERS}" != "core" ]; then DOCKER_VERS="php${ver}"; fi

  echo "Testing ${DOCKER_VERS}"

  docker load --input .compiled/$DOCKER_NAME.tar
  docker run --name $DOCKER_NAME -d $DOCKER_TEMP:$DOCKER_VERS $

  echo "Waiting for container to be up and running (timeout 10 seconds)..."
  sleep 10

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
