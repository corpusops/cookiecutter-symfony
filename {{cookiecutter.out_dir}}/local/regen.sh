#!/usr/bin/env bash
W="$(cd $(dirname $(readlink -f "$0"))/ && pwd)"
vv() { echo "$@">&2;"$@"; }
dvv() { if [[ -n "${DEBUG-}" ]];then echo "$@">&2;fi;"$@"; }
reset
out2="$( cd "$W/.." && pwd)"
out="$(dirname $out2)/$(basename $out2)_pre"
venv=${venv:-$HOME/tools/cookiecutter/activate}
if [ -e "$venv/bin/activate" ];then . "$venv/bin/activate";fi
set -e
if [[ -n "$1" ]] && [ -e $1 ];then
    COOKIECUTTER="$1"
    shift
fi
# $1 maybe a dir or an argument
u=${COOKIECUTTER-}
if [[ -z "$u" ]];then
    u="$HOME/.cookiecutters/cookiecutter-{{cookiecutter.app_type}}"
    if [ ! -e "$u" ];then
        u="https://github.com/corpusops/$(basename $u).git"
    else
        cd "$u"
        git fetch origin
        git pull --rebase
    fi
fi
if [ -e "$out" ];then vv rm -rf "$out";fi
vv cookiecutter --no-input -o "$out" -f "$u" \
    {% for i, val in cookiecutter.items() %}{% if
        i not in ['_output_dir', 'out_dir', '_template']%}{{i}}="{{val.replace('$', '\$')}}" \
    {%endif%}{%endfor %} "$@"

# to finish template loop
# sync the gen in a second folder for intermediate regenerations
dvv rsync -aA \
    $(if [[ -n $DEBUG ]];then echo "-v";fi )\
    --include local/regen.sh \
    --exclude "local/*" --exclude lib \
    $( if [ -e ${out2}/.git ];then echo "--exclude .git";fi; ) \
    $( if [ -L ${out2}/Dockerfile ];then echo "--exclude Dockerfile";fi; ) \
    "$out/" "${out2}/"

( cd "$out2" && git add -f local/regen.sh || /bin/true)
dvv cp -f "$out/local/regen.sh" "$out2/local"

add_submodules() {
    cd "$out"
    while read submodl;do
        submodu="$(echo $submodl|awk '{print $2}')"
        submodp="$(echo $submodl|awk '{print $1}')"
        cd "$out2"
        if [ ! -e "$submodp" ];then
            git submodule add -f "$submodu" "$submodp"
        fi
        cd "$out"
    done < <(\
        git submodule foreach -q 'echo $path `git config --get remote.origin.url`'
    )
    cd "$W"
}
( add_submodules )
if [[ -z ${NO_RM-} ]];then dvv rm -rf "${out}";fi
echo "Your project is generated in: $out2" >&2
echo "Please note that you can generate with the local/regen.sh file" >&2
# vim:set et sts=4 ts=4 tw=80:
