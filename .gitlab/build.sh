for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"

  echo "Building ${DOCKER_VERS} from "${CI_COMMIT_BRANCH}""

  [[ "${CI_COMMIT_BRANCH}" = "master" ]] && NOT_DUMMY_SSL=true || NOT_DUMMY_SSL=false

  if [ "${DOCKER_VERS}" = "core" ]; then
    docker build --no-cache -t $DOCKER_TEMP:$DOCKER_VERS --build-arg NOT_DUMMY_SSL=$NOT_DUMMY_SSL .
  else
    docker build -t $DOCKER_TEMP:$DOCKER_VERS --build-arg PHP_VERSION=$DOCKER_VERS --build-arg NOT_DUMMY_SSL=$NOT_DUMMY_SSL .
  fi

done

exit 0
