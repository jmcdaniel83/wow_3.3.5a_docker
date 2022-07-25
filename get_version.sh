repo=https://github.com/TrinityCore/TrinityCore.git
branch=3.3.5

# get the latest version number
git ls-remote ${repo} refs/heads/${branch} | cut -c1-10

# EOF

