for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"
  DOCKER_NAME="${DOCKER_TEMP}-${DOCKER_VERS}"

  echo "Building ${DOCKER_VERS} from "${CI_COMMIT_BRANCH}""

  if [ "${DOCKER_VERS}" = "core" ]; then
    docker build --no-cache -t $DOCKER_TEMP:$DOCKER_VERS --build-arg NOT_DUMMY_SSL=false .
    docker save -o .compiled/$DOCKER_NAME.tar $DOCKER_TEMP:$DOCKER_VERS
  else
    docker build -t $DOCKER_TEMP:php$DOCKER_VERS --build-arg PHP_VERSION=$DOCKER_VERS --build-arg NOT_DUMMY_SSL=false .
    docker save -o .compiled/$DOCKER_NAME.tar $DOCKER_TEMP:php$DOCKER_VERS
  fi

done

exit 0
