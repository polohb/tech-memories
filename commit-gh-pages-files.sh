#!/bin/bash

if [ ! -f hugo ];then
    echo "Download hugo v0.51 ..."
    wget -O hugo.tgz https://github.com/gohugoio/hugo/releases/download/v0.51/hugo_0.51_Linux-64bit.tar.gz
    tar xvzf hugo.tgz hugo
    rm -rf hugo.tgz
fi

# generate site
./hugo

# commit to gh pages
cd public
git add --all
git commit
cd ..


# push to gh-pages
#git push origin gh-pages
