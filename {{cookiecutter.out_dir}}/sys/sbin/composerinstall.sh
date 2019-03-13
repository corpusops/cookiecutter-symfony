#!/bin/bash
SDEBUG=${SDEBUG-}
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
cd "$SCRIPTSDIR/.."
TOPDIR=$(pwd)

# now be in stop-on-error mode
set -e
# load locales & default env
# load this first as it resets $PATH
for i in /etc/environment /etc/default/locale;do
    if [ -e $i ];then . $i;fi
done

# activate shell debug if SDEBUG is set
if [[ -n $SDEBUG ]];then set -x;fi


PROJECT_DIR=$TOPDIR
if [ -e app ];then
    PROJECT_DIR=$TOPDIR/app
fi
export PROJECT_DIR

export APP_TYPE="${APP_TYPE:-symfony}"
export APP_USER="${APP_USER:-$APP_TYPE}"
export APP_GROUP="$APP_USER"

if [ -e $SCRIPTSDIR/pre-composer.sh ]; then
    $SCRIPTSDIR/pre-composer.sh
fi
(
    cd $PROJECT_DIR \
    && gosu $APP_USER /usr/local/bin/composer install  --prefer-dist --optimize-autoloader $@
)
