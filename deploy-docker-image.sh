#!/bin/bash -e

TAG="${TRAVIS_TAG:-$(git describe --always --tags)}"

retry() {
    "${@}" || "${@}" || exit 2
}


login() {
  echo "Logging into Docker Hub"
  retry docker login \
      "--username=${DOCKER_USERNAME}" \
      "--password=${DOCKER_PASSWORD}"
}


buildPush() {
  IMAGE="${1}"
  DOCKERFILE="${2:-Dockerfile}"

  echo "Building docker image"
  retry docker pull "${IMAGE}"
  retry docker build -t "${IMAGE}" -t "${IMAGE}:${TAG}" -f "${DOCKERFILE}" --build-arg FROM_TAG="${TAG}" --cache-from "${IMAGE}" .

  echo "Pushing image to ${IMAGE}:${TAG}"
  retry docker push "${IMAGE}:${TAG}"
  retry docker push "${IMAGE}"
}


logout() {
  echo "Logging out""${@}"
  retry docker logout
}

deployQA() {
  echo "Deploying to QA"
  curl -X POST \
    -F token=${DEPLOY_QA_TOKEN} \
    -F ref=master \
    -F variables[APP_NAME]='next' \
    -F variables[NEW_TAG]=${TAG} \
    https://gitlab.cern.ch/api/v4/projects/62928/trigger/pipeline
 }


main() {
  login
  buildPush "inspirehep/next"
  buildPush "inspirehep/next-assets" Dockerfile.with_assets
  buildPush "inspirehep/next-scrapyd" Dockerfile.scrapyd
  logout
  deployQA
}
main
