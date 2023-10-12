#!/bin/bash
#
# Bulid/deployment script for www.rust-bitcoin.org

set -e

root=$(pwd)

main() {
    local _deploy=false

    if [ "$#" -eq 1 ]; then
        if [ "$1" = "--deploy" ]; then
            _deploy=true
        fi
    fi

    if [ $_deploy = true ]; then
        deploy
    else
        build
        echo ""
        echo -e "\033[0;32m Site built, you can serve locally by cd'ing into site/ and running 'hugo serve'...\033[0m"
    fi
}

build() {
    # Build the cookbook
    cd $root
    rm -rf "site/static/book"
    cd cookbook
    mdbook build --dest-dir "../site/static/book"
    cd $root

    # Build the hugo project.
    cd site
    hugo
    cd $root
}

# Deploy the site to https://github.com/rust-bitcoin/rust-bitcoin.github.io
deploy() {
    local _date=$(date --utc)
    echo -e "\033[0;32m Deploying site to GitHub...\033[0m"
    cd $root

    local branch=$(git rev-parse --abbrev-ref HEAD)

    if [ $branch != "master" ]; then
        echo "Not on master branch, must be on master to deploy"
        return 1
    fi

    build

    # Commit changes.
    cd site/public
    git add -A

    msg="Build site `date`"
    if [ $# -eq 1 ]
    then msg="$1"
    fi
    git commit -m "$msg"

    # Push html to GitHub pages (see public/.git/config)
    git push

    cd $root
    echo -e "\033[0;32m Deployment successful\033[0m"
}

#
# Main
#
main $@
exit 0
