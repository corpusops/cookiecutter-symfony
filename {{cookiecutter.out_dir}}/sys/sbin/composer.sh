#!/bin/bash
SDEBUG=${SDEBUG-}
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
SHELL_USER=${SHELL_USER-}
cd "$SCRIPTSDIR/../.."
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

if [ "x${SHELL_USER}" = "x${APP_USER}" ]; then
    GOSU_CMD=""
else
    GOSU_CMD="gosu $APP_USER"
fi

if [ -e $SCRIPTSDIR/pre-composer.sh ]; then
    $SCRIPTSDIR/pre-composer.sh
fi
(
    cd $PROJECT_DIR \
    && $GOSU_CMD /usr/local/bin/composer clear-cache \
    {%if cookiecutter.base_os=='centos'%}&& $GOSU_CMD echo "afwully disabling tls, seems CentOS+TLS is bad for https://codeload.github.com" \
    && $GOSU_CMD /usr/local/bin/composer config -g disable-tls true {%endif%}\
    && $GOSU_CMD /usr/local/bin/composer --verbose $@
)
