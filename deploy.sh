#!/usr/bin/env bash

set -e -o pipefail

fail() {
  echo "$@" >&2
  exit 1
}

minikubeRunning() {
  minikube status >/dev/null 2>&1
}

minikubeStart() {
  local maxAttempts=3
  until minikubeRunning ; do
    minikube start
    maxAttempts=$((maxAttempts-1))
    [ ${maxAttempts} -gt 0 ] || break
  done
  minikubeRunning
}

minikubeEnv() {
  eval $(minikube -p minikube docker-env)
}

minikubeStop() {
  minikube stop
}

appDeploy() {
  local app="$1"
  kubectl apply -f ${app}/${app}.yaml
}

challengeDestroy() {
  kubectl delete deployments.apps,service,configMaps -l part-of=challenge
}

main() {
  local apps="invoice-app payment-provider"
  local forceFlag=0
  local destroyFlag=0
  while [ $# -gt 0 ] ; do
    case "$1" in
      -f|--force)
        forceFlag=1
        shift
        ;;
      -d|--destroy)
        destroyFlag=1
        shift
        ;;
      *)
        fail "unknown argument '$1'"
        ;;
    esac
  done
  minikubeStart || fail "unable to start minikube"
  minikubeEnv
  [ ${forceFlag} -eq 0 -a ${destroyFlag} -eq 0 ] || challengeDestroy
  [ ${destroyFlag} -eq 0 ] || exit
  for app in ${apps} ; do
    appDeploy ${app}
  done
}

main "$@"
