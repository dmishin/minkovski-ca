#!/bin/sh
SITEDIR=../homepage-sources
ODIR=$SITEDIR/res/minkovski-ca

set -e

echo ===========================
echo ==  Publishing Minkovski-ca  ==
echo ===========================


cp -r index.html application.js *.css LICENSE.MIT README.md $ODIR


echo =============================================
echo ==  Done building, now publishing on site  ==
echo =============================================

cd $SITEDIR
sh ./publish.sh
