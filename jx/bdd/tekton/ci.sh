#!/usr/bin/env bash
set -e
set -x

export GH_USERNAME="jenkins-x-versions-bot-test"
export GH_OWNER="jenkins-x-versions-bot-test"

# fix broken `BUILD_NUMBER` env var
export BUILD_NUMBER="$BUILD_ID"

JX_HOME="/tmp/jxhome"
KUBECONFIG="/tmp/jxhome/config"

# lets avoid the git/credentials causing confusion during the test
export XDG_CONFIG_HOME=$JX_HOME

mkdir -p $JX_HOME/git

# TODO hack until we fix boot to do this too!
helm init --client-only --stable-repo-url https://charts.helm.sh/stable
helm repo add jenkins-x https://jenkins-x-charts.github.io/repo

jx install dependencies --all

jx version --short

# replace the credentials file with a single user entry
echo "https://$GH_USERNAME:$GH_ACCESS_TOKEN@github.com" > $JX_HOME/git/credentials

gcloud auth activate-service-account --key-file $GKE_SA

# lets setup git 
git config --global --add user.name JenkinsXBot
git config --global --add user.email jenkins-x@googlegroups.com

echo "running the BDD tests with JX_HOME = $JX_HOME"

# test configuration
export SKIP_JENKINS_CHECK="yes"

# Just run the golang-http-from-jenkins-x-yml import test here
export BDD_TEST_SINGLE_IMPORT="golang-http-from-jenkins-x-yml"

jx step bdd \
    --use-revision \
    --version-repo-pr \
    --versions-repo https://github.com/jenkins-x/jenkins-x-versions.git \
    --config jx/bdd/tekton/cluster.yaml \
    --gopath /tmp \
    --git-provider=github \
    --git-username $GH_USERNAME \
    --git-owner $GH_OWNER \
    --git-api-token $GH_ACCESS_TOKEN \
    --default-admin-password $JENKINS_PASSWORD \
    --no-delete-app \
    --no-delete-repo \
    --tests install \
    --tests test-verify-pods \
    --tests test-upgrade-ingress \
    --tests test-app-lifecycle \
    --tests test-quickstart-golang-http \
    --tests test-single-import
