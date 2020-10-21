for ver in $DOCKER_ARGS; do

  DOCKER_VERS="${ver}"

  echo "Bulding ${DOCKER_VERS} from "${CI_COMMIT_BRANCH}""

  if [ "${DOCKER_VERS}" = "core" ]; then
    docker build --no-cache -t $DOCKER_TEMP:$DOCKER_VERS .
  else
    docker build -t $DOCKER_TEMP:$DOCKER_VERS --build-arg PHP_VERSION=$DOCKER_VERS --build-arg BUILD_BRANCH=$CI_COMMIT_BRANCH .
  fi

done

exit 0
