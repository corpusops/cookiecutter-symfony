#!/bin/bash
SDEBUG=${SDEBUG-}
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
# now be in stop-on-error mode
set -e
# load locales & default env
# load this first as it resets $PATH
for i in /etc/environment /etc/default/locale;do
    if [ -e $i ];then . $i;fi
done

# activate shell debug if SDEBUG is set
if [[ -n $SDEBUG ]];then set -x;fi

export APP_TYPE="${APP_TYPE:-symfony}"
export APP_USER="${APP_USER:-$APP_TYPE}"
export APP_GROUP="$APP_USER"
(
    gosu $APP_USER ssh-keyscan gitlab.makina-corpus.net >> /home/$APP_USER/.ssh/known_hosts \
    && gosu $APP_USER ssh-keyscan 37.58.212.66 >> /home/$APP_USER/.ssh/known_hosts \
    && chown $APP_USER:$APP_USER /home/$APP_USER/.ssh/known_hosts \
    && gosu $APP_USER printf 'Host gitlab.makina-corpus.net\n Preferredauthentications publickey\n  IdentityFile /home/symfony/.ssh/id_irp_comon_deploy\nHost 37.58.212.66\n Preferredauthentications publickey\n  IdentityFile /home/symfony/.ssh/id_irp_comon_deploy\n' > /home/$APP_USER/.ssh/config \
    && gosu $APP_USER ls -alh  /home/$APP_USER/.ssh/ \
)