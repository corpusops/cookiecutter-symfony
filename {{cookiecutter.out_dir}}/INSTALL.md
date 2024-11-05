{%- set envs = ['dev', 'qa', 'staging', 'prod', 'preprod'] %}
{%- set aenvs = [] %}{%- for i in envs %}{% if cookiecutter.get(i+'_host', '')%}{% set _ = aenvs.append(i) %}{%endif%}{%endfor%}
{%- set refenv = aenvs|length > 1 and aenvs[-2] or aenvs[-1] %}
# Initialize your development environment

All following commands must be run only once at project installation.

## TL;LR
```bash
git clone --recursive {{cookiecutter.git_project_url}} # choose between ssh and http
{%-if cookiecutter.use_submodule_for_deploy_code-%}
cd {{cookiecutter.git_project}}
git submodule init # only the fist time
git submodule update --recursive
{%-endif%}
./control.sh init
./control.sh build
 # start db
./control.sh up db
./control.sh dcompose logs db # verify ok & <C-C>
./control.sh up --no-deps setup-{{cookiecutter.db_mode}}
./control.sh dcompose logs setup-{{cookiecutter.db_mode}} # verify ok & <C-C>
# get & load dump or init db
# bootstrap local dev symfony setup
./control.sh up --no-deps mailcatcher symfony
./control.sh userexec bin/composerinstall
./control.sh up --no-deps --force-recreate symfony symfony-supervisor
# init db
./control.sh console doctrine:migrations:migrate --no-interaction --allow-no-migration
# or load a dump with
# cat local/dump.sql|./control.sh dcompose exec -T db sh -ec 'mysql --password=$MYSQL_PASSWORD --user=$MYSQL_USER $MYSQL_DATABASE'
./control.sh userexec bin/console assets:install
# add site to /etc/hosts
sudo sed  -i -re "/{{cookiecutter.local_domain }}/ d;$ a 127.0.0.1 {{cookiecutter.local_domain}}" /etc/hosts
./control.sh up --force-recreate --no-deps nginx
./control.sh dcompose logs -f nginx # & wait to see
  nginx_1               | nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
  nginx_1               | nginx: configuration file /etc/nginx/nginx.conf test is successful
# visit https://{{cookiecutter.local_domain}}:8553/
```

## First clone

```bash
git clone --recursive {{cookiecutter.git_project_url}} # choose between ssh and http
{%-if cookiecutter.use_submodule_for_deploy_code-%}cd {{cookiecutter.git_project}}
git submodule init # only the fist time
git submodule update --recursive
{%-endif%}
```

## Before using any ansible command: a note on sudo

If your user is ``sudoer`` but is asking for you to input a password before elavating privileges,
You will need to add ``--ask-become-pass`` (or in earlier ansible versions: ``--ask-sudo-pass``) and maybe ``--become`` to any of the following ``ansible alike`` commands.

## Install docker and docker compose

If you are under Debian/Ubuntu/Mint/CentOS and **if you do not already have** docker, docker-compose and corpusops on your PC, you can do the following:

```bash
.ansible/scripts/download_corpusops.sh
.ansible/scripts/setup_corpusops.sh
local/*/bin/cops_apply_role --become \
    local/*/*/corpusops.roles/services_virt_docker/role.yml
```

... or follow official procedures for
[docker](https://docs.docker.com/install/#releases) and
[docker-compose](https://docs.docker.com/compose/install/).

## Update corpusops

You may have to update corpusops time to time with:

```bash
./control.sh up_corpusops
```

## Configuration

Use the wrapper to init configuration files from their ``.dist`` counterpart
and adapt them to your needs.

```bash
./control.sh init
```

## Login to the app docker registry

You need to login to our docker registry to be able to use it:


```bash
# read below how to get a token before doing it
docker login {{cookiecutter.docker_registry}}  # Use your GitLab account.
```

{%- if cookiecutter.registry_is_gitlab_registry %}
**⚠️ See also ⚠️** the
    [project docker registry]({{cookiecutter.git_project_url.replace('ssh://', 'https://').replace('git@', '')}}/container_registry)
{%- else %}
**⚠️ See also ⚠️** the [makinacorpus doc in the docs/tools/dockerregistry
section](https://docs.makina-corpus.net/tools/dev_dockerregistry/) to know how to get the docker registry token.

You'll have to login on the docker registry using the 'gitlab sso' button, generate a token to use as a password and this token will only be visible for a few seconds (and it's very small and hard to see). Check the link for details.
{%- endif%}

Without the docker login step you can still run the project but you will not be able to **pull** existing images, you'll have to make a local **build**.

# Use your development environment

## Update submodules

Never forget to grab and update regularly the project submodules:

```bash
git pull{% if cookiecutter.use_submodule_for_deploy_code
%}
git submodule init # only the fist time
git submodule update --recursive{%endif%}
```

## Control.sh helper

You may use the stack entry point helper which has some neat helpers but feel
free to use docker command if you know what your are doing.

```bash
./control.sh usage # Show all available commands
```

## Start the stack

After a last verification of the files, to run with docker, just type:

```bash
# First time you download the app, or sometime to refresh the image
./control.sh pull # Call the docker compose pull command
./control.sh up # Should be launched once each time you want to start the stack
```

You may need some alteration on your local ``/etc/hosts`` to reach the site using
domains and ports declared in docker-compose.yml (or docker.env if you have overrides).

For example if you have:

```bash
grep ABSOLUTE docker-compose.yml
ABSOLUTE_URL_SCHEME=http
ABSOLUTE_URL_DOMAIN={{cookiecutter.local_domain}}
ABSOLUTE_URL_PORT=:{{cookiecutter.local_http_port}}
```

The project should be reached in http://{{cookiecutter.local_domain}}:{{cookiecutter.local_http_port}} and {{cookiecutter.local_domain}} must resolve to ``127.0.0.1``.

{%if cookiecutter.ssl_in_dev%}

If you have:

```bash
grep ABSOLUTE docker-compose.yml
ABSOLUTE_URL_SCHEME=https
ABSOLUTE_URL_DOMAIN={{cookiecutter.local_domain}}
ABSOLUTE_URL_PORT=:{{cookiecutter.local_https_port}}
```
Then ``{{cookiecutter.local_domain}}`` stills need to resolve to ``127.0.0.1`` but the access will be <https://{{cookiecutter.local_domain}}:{{cookiecutter.local_https_port}}> .

{% endif %}

The first time you launch the `up` command on your local environment,
the application is not yet installed. Shared directories with your local
installation, containing things like the *vendors*, are empty, and the
database may also be empty. A first test may need commands like these
ones:

```bash
./control.sh up
./control.sh userexec bin/composerinstall
./control.sh console doctrine:migrations:migrate --no-interaction --allow-no-migration
# or custom commands if they exist
./control.sh console system:database:install --reset --test-data
```

## Troubleshoot problems

You may need to check for problems by listing containers and checking logs with

```bash
./control.sh ps
# here finding a line like this one:
foobar_{{cookiecutter.app_type}}_1_4a022a7c19bd              /bin/sh -c dockerize -wait ...   Exit 1
# note the exit 1 is not a good news...
# asking for logs
docker logs -f foobar_{{cookiecutter.app_type}}_1_4a022a7c19bd
```


In case of problems in the ``init.sh`` script of the symfony container you
can add some debug by adding a SDEBUG key in the env of the container,
you can have even more details by adding an empty NO\_STARTUP\_LOG env.
So, for example, edit your ``docker.env`` script and add:

```bash
SDEBUG=1
NO_STARTUP_LOG=
```

## Start a shell inside the symfony container

- for user shell

```bash
./control.sh usershell
# or
./control.sh userexec
```

- for root shell

```bash
./control.sh shell
# or
./control.sh exec
```

**⚠️ Remember ⚠️** to use `./control.sh up` to start the stack before.

## Run plain docker-compose commands

- Please remember that the ``CONTROL_COMPOSE_FILES`` env var controls
which docker-compose configs are use (list of space separated
files), by default it uses the dev set.

```bash
./control.sh dcompose <ARGS>
```

## Rebuild/Refresh local docker image in dev

```bash
control.sh buildimages
```

## Calling Symfony console commands

```bash
./control.sh console [options]
# For instance:
# ./control.sh console doctrine:migrations:migrate --allow-no-migration
# ./control.sh console cache:clear
# ...
# or:
./control.sh userexec "bin/console [options]"
```

**⚠️ Remember ⚠️** to use `./control.sh up` to start the stack before.

## Run tests

```bash
./control.sh tests
# also consider: linting|coverage
```

**⚠️ Remember ⚠️** to use `./control.sh up` to start the stack before.

## File permissions

If you get annoying file permissions problems on your host in development, you can use the following routine to (re)allow your host
user to use files in your working directory


```bash
./control.sh open_perms_valve
```

## Docker volumes

Your application extensivly use docker volumes. From times to times you may
need to erase them (eg: burn the db to start from fresh)

```bash
docker volume ls  # hint: |grep \$app
docker volume rm $id
```

## Reusing a precached image in dev to accelerate rebuilds
Once you have build once your image, you have two options to reuse your image as a base to future builds, mainly to accelerate buildout successive runs.

- Solution1: Use the current image as an incremental build: Put in your .env

    ```bash
    {{cookiecutter.app_type.upper()}}_BASE_IMAGE={{ cookiecutter.docker_image }}:latest-dev
    ```

- Solution2: Use a specific tag: Put in your .env

    ```bash
    {{cookiecutter.app_type.upper()}}_BASE_IMAGE=a tag
    # this <a_tag> will be done after issuing: docker tag registry.makina-corpus.net/mirabell/chanel:latest-dev a_tag
    # this <a_tag> will be done after issuing: docker tag {{ cookiecutter.docker_image }}:latest-dev a_tag
    ```

## Integrating an IDE


### Using VSCode

Adding this to ``.vscode/settings.json`` would help to give you a smooth editing experience.

```json
{
"breadcrumbs.enabled": true,
"css.validate": true,
"diffEditor.ignoreTrimWhitespace": false,
"editor.tabSize": 4,
"editor.autoIndent": "full",
"editor.insertSpaces": true,
"editor.formatOnPaste": true,
"editor.formatOnSave": true,
"editor.renderControlCharacters": true,
"editor.renderWhitespace": "boundary",
"editor.wordWrapColumn": 100,
"editor.wordWrap": "bounded",
"editor.detectIndentation": true,
"editor.rulers": [
100
],
"files.associations": {
"*.php": "php",
"*.html.twig": "twig"
},
"files.trimTrailingWhitespace": true,
"files.insertFinalNewline": true,
"html.format.enable": true,
"html.format.wrapLineLength": 80,
"telemetry.enableTelemetry": false,

/* Empty Indent */
"emptyIndent.removeIndent": true,
"emptyIndent.highlightIndent": false,
"emptyIndent.highlightColor": "rgba(246,36,89,0.6)",

// Validate --------
"php.validate.enable": true,
"php.validate.run": "onType",

// IntelliSense --------
"php.suggest.basic": false,

// Intelephense.
"intelephense.environment.documentRoot": "app/public/index.php",
"intelephense.format.enable": false,
"php-docblocker.gap": true,
"php-docblocker.useShortNames": true,
"emmet.includeLanguages": {
"twig": "twig"
},
"files.eol": "\n",
"files.watcherExclude": {
"**/.git/objects/**": true,
"**/.git/subtree-cache/**": true,
"**/node_modules/*/**": true,
"**/local/*/**": true
}
}
```

### Recommended vscode extensions:

- PHP intelephense (and not Intellisense)
- PHP debug
- (...)


### Debugging with VSCode

Create a .vscode/launch.json config file:

```json
{
"version": "0.2.0",
"configurations": [
    {
        "name": "Listen in 9000",
        "type": "php",
        "request": "launch",
        "pathMappings": {
            "/code/": "${workspaceFolder}"
        },
        "xdebugSettings": {
            "max_data": 65535,
            "show_hidden": 1,
            "max_children": 100,
            "max_depth": 5
        },
        "port": 9000,
        "log": true,
        "externalConsole": false,
        "ignore": [
            "**/vendor/**/*.php"
        ]
    }
]
}
```

Open the debug view in VSCode (CTRL+Shift+D), and start the listener named "Listen in 9000" (green arrow).

Add your breakpoint in code.

Visit the site with the XDEBUG argument, like: http://{{cookiecutter.local_domain}}:{{cookiecutter.local_http_port}}/something?XDEBUG_SESSION_START=foo

And that's it.

## Doc for deployment on environments
- [See here](./docs/README.md)

## FAQ

If you get troubles with the nginx docker env restarting all the time, try recreating it :

```bash
docker-compose -f docker-compose.yml -f docker-compose-dev.yml up -d --no-deps --force-recreate nginx backup
```

If you get the same problem with the {{cookiecutter.app_type}} docker env :

```bash
docker-compose -f docker-compose.yml -f docker-compose-dev.yml stop {{cookiecutter.app_type}} db
docker volume rm {{cookiecutter.lname}}-postgresql # check with docker volume ls
docker-compose -f docker-compose.yml -f docker-compose-dev.yml up -d db
# wait for database stuff to be installed
docker-compose -f docker-compose.yml -f docker-compose-dev.yml up {{cookiecutter.app_type}}
```

## Pipelines workflows tied to deploy environments and built docker images
### TL;DR
- We use deploy branches where some git **branches** (main branch, tags, and environment related branches) are dedicated to deploy related **gitlab**, **configuration managment tool's environments**, and **docker images tags**.<br/>
- You can use them to deliver to a specific environment either by:
    1. Not using promotion workflow and only pushing to this branch and waiting for the whole pipeline to complete the image build, and then deploy on the targeted env.
    2. Using tags promotion: "Docker Image Promotion is the process of promoting Docker Images between registries to ensure that only approved and verified images are used in the right environments, such as production."<br/>
        - You **run or has run a successful pipeline with the code you want to deploy**, (surely ``{{cookiecutter.main_branch}}`` or a specific Tag).
        - You can then **``promote`` its related docker tag** to either **one or all** env(s) with the ``promote_*`` jobs and reuse the previously produced tag.<br/>
        - After the succesful promotion, you can then manually **deploy on the targeted env(s)**.
        - TIP: The Promote & Deploy steps can be done at once using the `promote_and_deploy_*` jobs.

### Using promotion in practice
- As an example, we are taking <br/>
  &nbsp;&nbsp;&nbsp;&nbsp;the ``{{refenv}}`` branch which is tied to <br/>
  &nbsp;&nbsp;&nbsp;&nbsp;the {{refenv}} **inventory ansible group**<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;and deliver the {{refenv}} **docker image**<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;and associated resources on the **{{refenv}} environment**.
- First, run an entire pipeline on the branch (eg:``{{cookiecutter.main_branch}}``) and the commit you want to deploy.<br/>
  Please note that it can also be another branch like `stable` if `stable` branch was configured to produce the `stable` docker tags via the `TAGGUABLE_IMAGE_BRANCH` [`.gitlab-ci.yml`](./.gitlab-ci.yml) setting.
- Push your commit to the desired related env branche(s) (remove the ones you won't deploy now) to track the commit you are deploying onto

    ```bash
    # on local main branch
    git fetch --all
    git reset --hard origin/{{cookiecutter.main_branch}}
    git push --force origin{% for i in aenvs %} HEAD:{{i}}{%endfor %}
    ```
    1. Go to your gitab project ``pipelines`` section and immediately kill/cancel all launched pipelines.
    2. Find the killed pipeline on the environment (branch) you want to deploy onto (and if you don't have it, launch one via the ``Run pipeline`` button and **immediatly kill** it),<br/>
       Click on the ``canceled/running`` button link which links the pipeline details), <br/>
       It will lead to a jobs dashboard which is really appropriated to complete next steps.<br/>
       Either run:
        - one of the `promote_and_deploy_*` available on the main branch (``{{cookiecutter.main_branch}}``), Tags, Or the deploy branch related to the deployed environment.
        - or
            - ``promote_all_envs``: promote all deploy branches with the selected ``FROM_PROMOTE`` tag (see just below).
            - ``promote_single_env``: promote only this env with the selected ``FROM_PROMOTE`` tag (see just below).
        - Indeed, **in both jobs**, you can override the default promoted tag which is ``latest`` with the help of that ``FROM_PROMOTE`` pipeline/environment variable.<br/>
          This can help in those following cases:
            - If you want `production` to be deployed with the `dev` image, you can then set `FROM_PROMOTE=dev`.
            - If you want `dev` to be deployed with the `stable` image produced by the `stable` branch, you can then set `FROM_PROMOTE=stable`.
    3. Upon successful promotion, run the ``manual_deploy_$env`` job. (eg: ``manual_deploy_dev``)

