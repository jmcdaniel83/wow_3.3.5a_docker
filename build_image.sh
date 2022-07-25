#!/bin/bash
export VERSION="0.1.1"

# =====================================
# Variables
# =====================================

GIT_REPO=https://github.com/TrinityCore/TrinityCore.git

# =====================================
# Docker Variables
# =====================================

USER=jaymac83

# =====================================
# Function Defintions
# =====================================

# Public: builds our current docker image.
#
# Takes the repository, tag, and docker tag that we will use to generate this
# latest image.
#
# $1 - The git repository that we are leveraging
# $2 - The git tag that we are building
# $3 - The docker tag that will be associated with this image
#
build_image() {
  echo "building with following arguments:"
  echo "git branch: $2"
  echo "git commit: $3"
  echo "docker tag: $1"
  docker build \
    --build-arg GIT_BRANCH=$2 \
    --build-arg GIT_COMMIT=$3 \
    -t ${USER}/wow:$1 .
}

# our logged in flag to specify if we have logged in or not
logged_in=0

# Logs us into the docker hub repository
log_in() {
  # login to docker hub
  docker login -u ${USER}

  # change logged in flag
  logged_in=1
}

# Pushes the provided tag up to docker hub account
#
# Takes the provided tag and will push the new tag up to docker hub.
#
# $1 - The git tag that was built
#
# @post synched current build with docker hub repository
#
push_image() {
  # tag the currently built with our remote tag
  #docker tag vulcan/wow:$1 ${user}/wow:$1
  docker push ${USER}/wow:$1
}

# Public: Will provide the commit SHA value for the provided repository and tag.
#
# Will provide back the commit SHA value of the provided git repository and tag
# combo.
#
# $1 - The git repository
# $2 - The git tag that we are interested in
#
# Returns the SHA value of the provided repo:tag combo
#
get_commit_sha() {
  git ls-remote $1 refs/heads/$2 | cut -c1-10
}

# Will read the previous commit from our last commit file
#
# sets the global variable prev_commit with the last commit
#
get_prev_commit() {
  # will get the previous commit that was placed into the commit file
  prev_commit=$(while read -r line; do echo "$line"; done < "./commit")
}

# =====================================
# Argument Handling
# =====================================

# $1 - The git branch that we are attempting to build, default 3.3.5
git_branch=$1
git_commit=$2

if [ -z ${git_branch} ]; then
  echo defaulting to 3.3.5 branch...
  git_branch=3.3.5
fi

tag_name=${git_branch}
if [ "${git_branch}" == "master" ]; then
  #tag_name=9.0.5
  tag_name=9.1.5
fi

if [ -z ${git_commit} ]; then
  # get the version of our current tag that is building
  echo retrieving latest commit...
  git_commit=$(get_commit_sha ${GIT_REPO} ${git_branch})
  echo "latest commit: ${git_commit}"
fi

# get the last commit
get_prev_commit

# make sure that we have a new commit to build
rebuilding=0
if [[ "${git_commit}" == "${prev_commit}" ]]; then
  echo -n "no new commits, rebuild? (y/n) "
  read rebuild

  if [[ "$rebuild" == "Y" || "$rebuild" == "y" ]]; then
    echo "rebuilding..."
    rebuilding=1
  else
    # we have nothing new to build
    echo "skipping..."
    exit 0
  fi
fi

# ==============================================================================
# Main
# ==============================================================================

# log in to the repostory
log_in

echo Building ${git_branch}-${git_commit}...

# generate our docker tag (version)
version_tag="${tag_name}-${git_commit}"
# build the image
build_image $version_tag $git_branch $git_commit
push_image ${version_tag}

# generate our docker tag (latest)
latest_tag="${tag_name}-latest"
# build the image
build_image $latest_tag $git_branch $git_commit
push_image ${latest_tag}

# update our files; if not rebuilding
if [ $rebuilding -ne 1 ]; then
  ## update commit file
  echo ${git_commit} > commit
  ## add to history file
  echo ${git_commit} >> commit_history
fi

# EOF
