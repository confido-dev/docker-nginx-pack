for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"

  echo "Building ${DOCKER_VERS} from "${CI_COMMIT_BRANCH}""

  if [ "${DOCKER_VERS}" = "core" ]; then
    docker build --no-cache -t $DOCKER_TEMP:$DOCKER_VERS --build-arg NOT_DUMMY_SSL=false .
  else
    docker build -t $DOCKER_TEMP:php$DOCKER_VERS --build-arg PHP_VERSION=$DOCKER_VERS --build-arg NOT_DUMMY_SSL=false .
  fi

done

exit 0
