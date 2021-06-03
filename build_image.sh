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
    echo "building with following arguments:"
    echo "git branch: $2"
    echo "git commit: $3"
    echo "docker tag: $1"
    docker build \
        --build-arg GIT_BRANCH=$2 \
        --build-arg GIT_COMMIT=$3 \
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
# $1 - The git branch that we are attempting to build
git_branch=$1

tag_name=${git_branch}
if [ "${git_branch}" == "master" ]; then
    tag_name=9.0.5
fi

# get the version of our current tag that is building
git_commit=$(get_commit_sha ${GIT_REPO} ${git_branch})

echo Building ${git_branch}::${git_commit}...

# generate our docker tag (version)
docker_tag="${tag_name}-${git_commit}"
## build the image
build_image $docker_tag $git_branch $git_commit

# generate our docker tag (latest)
docker_tag="${tag_name}-latest"
## build the image
build_image $docker_tag $git_branch $git_commit

# EOF
