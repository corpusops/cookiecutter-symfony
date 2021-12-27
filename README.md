# Init a Symfony project

Idea is to create it with a wonderful python tool called
[cookiecutter](https://github.com/audreyr/cookiecutter)

## Install prerequisites

```sh
if ! ( virtualenv 2>&1 >/dev/null );then echo "ERROR: install venv, on debian/ubuntu: apt install -y virtualenv,fi";fi
virtualenv --python=python3 ~/tools/cookiecutter
~/tools/cookiecutter/bin/pip install cookiecutter
```

### For MacOS users

Install gnu-sed with `brew install gsed` and use it as default with `export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"` for the focllowing commands.

## Create a new Symfony project
- create on gitlab your project (empty)
- then locally generate the base files (replace with your values)

    ```sh
    # If you already played with cookiecutter you have this directory with the
    # old project templates. You may need to refresh it.
    # ignore this step on first exec (you do not have it yet)
    cd ~/.cookiecutters/cookiecutter-symfony \
        && git fetch origin && git reset --hard origin/master \
        && cd -
    # activate cookiecutter env
    . ~/tools/cookiecutter/bin/activate
    # And launch the new 'foobar' project generation!
    # check most variables in cookiecutter.json file
    cookiecutter --no-input -f -o ~/out_dir \
        https://github.com/corpusops/cookiecutter-symfony.git \
        name=foobar \
        tld_domain=zorg.com \
        git_server=gitlab.makina-corpus.net \
        docker_registry= registry.makina-corpus.net \
        git_ns=zorg \
        local_http_port=8009 \
        maintenance_no_503="y" \
        dev_port=40001 staging_port=40003 qa_host="" prod_port=40010
    cd ~/out_dir
    # review before commit
    # for relative checkout to work, we need remote objects locally
    git commit local -m "Add deploy"
    ```

- Read [cookiecutter.json](./cookiecutter.json) for all options
-  notable options behaviors:
    - ``use_submodule_for_deploy_code=``: copy deploy submodule inside
      project for a standalone deployment (no common deploy)
    - ``local_http_port=NNNN``: local port use by devs to access the project after /etc/hosts edition to map 127.0.0.1 to the ``local_domain`` variable (something like http://project_name.local:local_http_port)
    - ``php_ver=X.Y``: php version to use
    - ``Symfony_ver=X.Y``: Symfony version to use
    - ``remove_cron=y``: will remove cron image and related configuration
    - ``enable_cron=``: will soft disable (comment crontab) without removing cron.
    - ``(qa|staging)_host=``: will disable generation for this env
    - ``tests_(staging|tests)=``: will disable those specific tests in CI
    - ``registry_is_gitlab_registry=y``: act that registry is gitlab based
      and use token to register image against and
      autofill ``register_user`` and ``registry_password``.
    - ``db_mode=<mode>``: one of ``postgres|postgis|mysql``
    - ``haproxy=y``: generate haproxy related jobs

- Push the generated files (here on `~/out_dir`) to your new project

### Check the extra needed contents

We provide a basic `app/composer.json` file. N**No doubt** that you may have to
complement it.

If you need access to one or more private git repositories for composer, you may
also need to add some private ssh keys in `keys/` directory and build a
`./sys/sbin/pre-composer.sh` script (it should look almost like the other
sys/sbin/composer scripts, but at the end you can add some ssh-keyscan and ssh
specifc configurations like this:)

```sh
(
    # && $GOSU_CMD ssh-keyscan 37.58.212.66 >> /home/$APP_USER/.ssh/known_hosts \
    $GOSU_CMD ssh-keyscan foo.example.com >> /home/$APP_USER/.ssh/known_hosts \
    && chown $APP_USER:$APP_USER /home/$APP_USER/.ssh/known_hosts \
    && $GOSU_CMD printf 'Host foo.example.com\n Preferredauthentications publickey\n  IdentityFile ...\n' > /home/$APP_USER/.ssh/config \
    && chown $APP_USER:$APP_USER /home/$APP_USER/.ssh/config
)
```

Check also the symfony migrate commands or anything needed in the created database.

## Init dev and and test locally


```sh
./control.sh init  # init conf files
./control.sh build symfony
./control.sh build  # will be faster as many images are based on symfony
```

Note that you can also read the generated README.md of the generated project for
details on how to deploy the project locally (like docker dependencies, debugging problems, etc).

If you launch a `up` action on dev local environement the application is not yet installed. Shared directories with your local installation, containing things like the *vendors*, are empty, and the database may also be empty. A first test may needs commands like these ones :

```sh
./control.sh up
./control.sh userexec bin/composerinstall
./control.sh console doctrine:migrations:migrate --allow-no-migration
```

## Fill ansible inventory

### Generate ssh deploy key
```ssh
cd local
ssh-keygen -t rsa -b 2048 -N '' -C deploy -f deploy
```

### Generate vaults password file
```sh
export CORPUSOPS_VAULT_PASSWORD=SuperVerySecretPassword
.ansible/scripts/setup_vaults.sh
```

- Also add that variable ``CORPUSOPS_VAULT_PASSWORD`` in the gitlab CI/CD variables
- You would certainly also add ``REGISTRY_USER`` & ``REGISTRY_PASSWORD``.

### Move vault templates to their encrypted counterparts

For each file which needs to be encrypted

```sh
# to find them
find .ansible/inventory/group_vars/|grep encrypt
```

### Generate vaults
Also open and read both your project top ``README.md`` and the ``.ansible/README.md``

You need to
1. open in a editor:

    ```sh
    $EDITOR .ansible/inventory/group_vars/dev/default.movemetoencryptedvault.yml
    ```
2. In another window/shell, use Ansible vault to create/edit that file without the "encrypted" in the filename and
copy/paste/adapt the content

    ```sh
    .ansible/scripts/edit_vault.sh .ansible/inventory/group_vars/dev/default.yml
    ```
3. Delete the original file

    ```sh
    rm -f .ansible/inventory/group_vars/dev/default.movemetoencryptedvault.yml
    ```

- Wash, rince, repeat for each needing-to-be-encrypted vault.
- ⚠️Please note⚠️: that you will need to put the previously generated ssh deploy key in ``all/default.yml``

## Push to gitlab
- Push to gitlab and run the dev job until it succeeds
- Trigger the dev image release job until it succeeds


## Deploy manually
- Deploy manually one time to see everything is in place<br/>
  Remember:
    - Your local copy is synced as the working directory on target env (with exclusions, see playbooks)
    - The ``cops_symfony_docker_tag`` controls which docker image is deployed.

    ```sh
    .ansible/scripts/call_ansible.sh .ansible/playbooks/deploy_key_setup.yml
    .ansible/scripts/call_ansible.sh -vvv .ansible/playbooks/ping.yml -l dev  # or staging
    .ansible/scripts/call_ansible.sh -vvv .ansible/playbooks/app.yml \
         -e "{cops_symfony_docker_tag: dev}" -l dev  # or staging
    ```

## Update project
You can regenerate at a later time the project
```sh
local/regen.sh  # and verify new files and updates
```
