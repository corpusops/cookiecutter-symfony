# Deployment documentation

- [Automatic deployment](./README.md#automatic)
- [Manual deployment](./README.md#manual)
- [More informations](./README.md#moreinformation)

# <a name="automatic"/>The CI/CD workflow aka. automatic deployment

Developer develop **using his localhost** with docker-compose **then he pushes**
it's commit to gitlab and **The CI/CD pipelines are thrown**:

## Docker image generation

- we pull if existing the previous docker image to speed up the build
- we warm the docker cache by unpackging previous
    relevant docker images which are in gitlab pipeline cache
- A new container image is build
- The image is saved in gitlab cache to be used in further process

## Test & linting

- we warm the docker cache by unpackging previous
    relevant docker images which are in gitlab pipeline cache
- Tests and other QA jobs are run under the built images

## Docker image Releasing

If tests are ok:

- If it is master or a tag, the image is pushed to the registry
    with the appropriate tag
- Otherwise, on any other branch, you can manually trigger a manual job to
 build the dev tag that will be autodeployed at a later stage on the
 dev/staging environment.

## In all cases, we teardown the test resources:

- test dockers (compose) are downed.
- If master/tag, TMP image is now a reference image in cache
    to speed up further builds
- TMP built image is deleted in other cases

## Deployment

- We deploy using an [ansible playbook](./README.md#details)
- For dev environment:
    - we autodeploy master and tags for dev environment
    - we await for manual operation to deploy any other branch/PR.
- For other envs than dev, we await for a manual, user,
    instruction to deploy on envs.

# <a name="manual"/>Manual deployment

## Configure ansible env

Adapt the ``.ansible/scripts/ansible_deploy_env.local`` file to your needs
 before starting the procedure.

## Download corpusops

**⚠️ Attention ⚠️** `./local/corpusops.bootstrap` folder must be empty for
cloning directly inside it.

```sh
.ansible/scripts/download_corpusops.sh
.ansible/scripts/setup_ansible.sh
```

## <a name="setupvault"/>Vault passwords setup

### <a name="vaultpassword"/>Generate vault password file

For each environment, setup first the `vault password file` that contains
your vault password. This will create the vaults files `~/.ansiblevault*env*`

```sh
# Replace here SUPER_SECRET_PASSWORD by the vault password
# Note the leading " " not to have the password in bash history
    CORPUSOPS_VAULT_PASSWORD='REPLACE_ME_BY_REAL_VAULT_PASSWORD' .ansible/scripts/setup_vaults.sh
```

- Also add that variable ``CORPUSOPS_VAULT_PASSWORD`` in the gitlab CI/CD variables
- You would certainly also add ``REGISTRY_USER`` & ``REGISTRY_PASSWORD``.

### <a name="sshkeyvaultsetup"/>Generate ssh deploy key

To <a name="sshkeygen"/> generate a ssh keypair if not present inside your
secret vault of you want to change it:

```sh
export A_ENV_NAME=deploy
ssh-keygen -t rsa -b 2048 -N '' -C $A_ENV_NAME -f $A_ENV_NAME
```

### <a name="sshkeyvaultsetup"/>Configure ssh keys and other secret in crypted vault

Use ansible-vault wrapper to create/edit your vault content:

```sh
# export A_ENV_NAME=<env>
.ansible/scripts/edit_vault.sh
```

will open a terminal with your vault and add it then to your crypted vault (`toto.pub`)
   file content in public, and the other in private.

```yaml
cops_deploy_ssh_key_paths:
    # replace by your env id used in the host definition inside your former inventory
    deploy:
    path: "{{'{{'}}'local/.ssh/deploy'|copsf_abspath}}"
    pub: |-
        ssh-rsa xxx
    private: |-
        -----BEGIN RSA PRIVATE KEY-----
        xxx
        -----END RSA PRIVATE KEY-----
```

You just edit the general vault name, but you can setup secret variables for
each env this way:

```sh
.ansible/scripts/edit_vault .ansible/inventory/group_vars/$A_ENV_NAME/default.yml
```

## <a name="sshdeploysetup"></a>GENERIC ssh setup

Generate from the vault inventory you just did, the ssh connection keyfile
  for ansible to connect to remote boxes (in ``./local/.ssh``)

```sh
# Generate SSH deploy key locally for ansible to work and dump
# the ssh key contained in inventory in a place suitable
# by ssh client (ansible)
.ansible/scripts/call_ansible.sh .ansible/playbooks/deploy_key_setup.yml
```

## Cleaning the ci cache on the staging VPS

When the remaining hard drive space happen to be low:
- connect to the CI runner
- delete everything inside ``/cache/*``

# More informations

## <a name="moreinformation">The big picture

The high level infrastructure:

```
  ~~~~~~~                                             /\
 / ^   ^ \                  +------------+           //\\
 | 0   0 |                  |  gitlab &  |          /// \\
  \  <   /                  |  gitlab-ci |<--<--<- //~~~~~\
   \____/                   +------------+        / ^   ^ \ -- ~ developers
       \                           |              | 0 < 0 |
        users >---->-- internet ------->------\   \   -  /
         |                         |           \   \____/
+++++++++++++++++++++++++++++++++++|+++++     +++++++++++++++++++++++++++++++
+  Preprod Cluster                 |    +     +  Prod Cluster               +
+     ssh: port: 22                |    +     +   ssh: port 22              +
+   +--haproxy: port 80/443        |    +     + l +--haproxy: port 80/443   +
+ l +--ssh: 4000x -> LXC ci runner |    +     + x +--ssh: 4000x -> LXC prod +
+ x +--ssh: 4000x -> LXC staging   |    +     + c |10.8.0.1                 +
+ c-+10.8.0.1                      |    +     +   |                         +
+   |  ++++++++++++++++++++++      |    +     + b |                         +
+ b |  | LXC CI: 10.8.0.x   |<--<--+    +     + r |                         +
+ r |  |   - gitlab runners |           +     + i |                         +
+ i |  ++++++++++++++++++++++           +     + d |                         +
+ d |      CI/CD Runners                +     + g |                         +
+ g |     +--launch deploys via ansible-+->+  + e | ++++++++++++++++++++++  +
+ e | +<--+ after producting docker images |  +   +-| LXC PROD: 10.8.0.x |<--+
+   | |             |                   +  +->-->-->|    - app in docker |  +|
+   | |             +->-->-->-->-->-->+ +     +     ++++++++++++++++++++++  +|
+   | |   +++++++++++++++++++++++++   | +     +                             +|
+   | +-->| LXC STAGING: 10.8.0.x |   | +     +                             +|
+   +-----|    - app in docker    |   | +     +                             +|
+         +++++++++++++++++++++++++   | +     +                             +|
++++++++++++++++++++++|+++++++++++++++|++     +++++++++++++++++++++++++++++++|
                      |               |  +-----------------+                 |
                      |               +->| Docker Registry |->-->-->-->-->-->+
                      +-<-<-<-<-<-<-<-<--|                 |
                                         +-----------------+
```

- The LXC CI running must be accessible in push from gitlab-ci
- The LXC CI running must be allowed
    - to pull and push from the docker registry
    - to access each lxc deploy env on it's ssh port
- Each deployment LXC host a containerized (docker) deployment
  of the application:

    ```
    LXC---DOCKER
            |
            +--- nginx: main reverse proxy
            |
            +--- {{cookiecutter.app_type}}: app
            |            (share a special 'static' & medias volume
            |             nginx which serve the application statis & medias)
            |
            +--- pgsql
            |
            +--- redis
            |
            +--- backup
            +--- ...
    ```

## Bootstrap env

[see install log](./log_install.md)

## <a name="details"/>Ansible deployment steps detail

The ansible playbook do:
- Sync code using rsync
- Generate
  - each docker env file (.env, docker.env)
  - Any app settings file
  - We try a most to put everything as ENV Variables to embrace the 12Factors principle.
- Pull images
- Install systemd launcher and start it
- Restart explictly each docker services
- Cleanup stale docker volumes


## Symfony settings setup
To add/modify symfony settings, you specifically need to edit ``.ansible/playbooks/roles/symfony_vars/defaults/main.yml`` for hosted deployments,<br/>
and adapt certainly one of ``cops_symfony_docker_env_freeform``, ``cops_symfony_docker_env_defaults``, ``cops_symfony_docker_env_extra``.
  - Here, never forget to abuse ansible variables to cut variables from their templates<br/>
    and put what's need to be in the general inventory and what needs to be crypted in the crypted vault.<br/>
    eg:
      - In all cases, adapt/edit inventory (variables may already exist)
        ```sh
        $EDITOR .ansible/playbooks/roles/symfony_vars/defaults/main.yml
        ```

          ```yaml
          # ...
          cops_symfony_docker_env_extra:
            MYSETTINGS={{'{{'}}cops_symfony_foobar}}
            MYSECRETSETTINGS={{'{{'}}cops_symfony_footruc}}
          ```
      - Set variables values in related clear group vars
        ```sh
        $EDITOR .ansible/inventory/group_vars/all/app.yml̀
        ```

          ```yaml
          # ...
          cops_symfony_foobar: supervalue
          ```

      - Set crypted values (see ansible/README about vaults) in related crypted group vars
        ```sh
        .ansible/scripts/edit_vault.sh  .ansible/inventory/group_vars/all/default.yml̀
        # for a specific env
        .ansible/scripts/edit_vault.sh  .ansible/inventory/group_vars/prod/default.yml̀
        ```

          ```yaml
          # ...
          cops_symfony_footruc: abcd123456789secret
          ```
