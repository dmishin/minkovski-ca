#!/bin/sh
SITEDIR=../homepage-sources
ODIR=$SITEDIR/res/minkovski-ca

set -e

echo ===========================
echo ==  Publishing Minkovski-ca  ==
echo ===========================


cp -r index.html help.html application.js mystyle.css icons.css latex.css LICENSE.MIT README.md icons.svg spinner.gif $ODIR


echo =============================================
echo ==  Done building, now publishing on site  ==
echo =============================================

cd $SITEDIR
sh ./publish.sh
