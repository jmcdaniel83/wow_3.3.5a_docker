#!/bin/bash
export VERSION="0.1.0"

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
    docker build \
        -t vulcan/wow:$1 .
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

# ==============================================================================
# Main
# ==============================================================================

GIT_REPO=git://github.com/TrinityCore/TrinityCore.git
# $1 - The git tag that we are attempting to build (branch)
git_tag=$1

# get the version of our current tag that is building
version=$(get_commit_sha ${GIT_REPO} ${git_tag})

echo Building ${git_tag}::${version}...

# generate our docker tag (latest)
docker_tag="${git_tag}-latest"
## build the image
#build_image $GIT_REPO $git_tag $docker_tag
build_image $docker_tag

# generate our docker tag (version)
docker_tag="${git_tag}-${version}"
## build the image
#build_image $GIT_REPO $git_tag $docker_tag
build_image $docker_tag

# EOF
