#!/usr/bin/env bash
set -e
set -x

export BB_USERNAME="jenkins-x-bdd"
export BB_OWNER="jxbdd"
export BB_EMAIL="jenkins-x@googlegroups.com"

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
echo "https://$BB_USERNAME:$BB_ACCESS_TOKEN@bitbucket.beescloud.com" > $JX_HOME/git/credentials

gcloud auth activate-service-account --key-file $GKE_SA

# lets setup git 
git config --global --add user.name JenkinsXBot
git config --global --add user.email jenkins-x@googlegroups.com

echo "running the BDD tests with JX_HOME = $JX_HOME"

# setup jx boot parameters
export JX_VALUE_ADMINUSER_PASSWORD="$JENKINS_PASSWORD"
export JX_VALUE_PIPELINEUSER_USERNAME="$BB_USERNAME"
export JX_VALUE_PIPELINEUSER_EMAIL="$BB_EMAIL"
export JX_VALUE_PIPELINEUSER_TOKEN="$BB_ACCESS_TOKEN"
export JX_VALUE_PROW_HMACTOKEN="$BB_ACCESS_TOKEN"

# TODO temporary hack until the batch mode in jx is fixed...
export JX_BATCH_MODE="true"

export BOOT_CONFIG_VERSION=$(jx step get dependency-version --host=github.com --owner=jenkins-x --repo=jenkins-x-boot-config --dir . | sed 's/.*: \(.*\)/\1/')

git clone https://github.com/jenkins-x/jenkins-x-boot-config.git boot-source
cd boot-source
git checkout tags/v${BOOT_CONFIG_VERSION} -b latest-boot-config
cp ../jx/bdd/boot-lh-bs/jx-requirements.yml .
cp ../jx/bdd/boot-lh-bs/parameters.yaml env


jx step bdd \
    --use-revision \
    --version-repo-pr \
    --versions-repo https://github.com/jenkins-x/jenkins-x-versions.git \
    --config ../jx/bdd/boot-lh-bs/cluster.yaml \
    --gopath /tmp \
    --git-provider bitbucketeserver \
    --git-provider-url https://bitbucket.beescloud.com \
    --git-owner $BB_OWNER \
    --git-username $BB_USERNAME \
    --git-api-token $BB_ACCESS_TOKEN \
    --default-admin-password $JENKINS_PASSWORD \
    --no-delete-app \
    --no-delete-repo \
    --tests install \
    --tests test-create-spring
