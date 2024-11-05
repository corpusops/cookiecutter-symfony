# log install
- To start, install deploy ssh pubkey in ``/root/.ssh/authorized_keys``
  of each server

## Remote access to your VPS, LXCs, configure your ~/.ssh/config
- edit your /etc/hosts if stack is not yet in DNS

    ```
    x.x.x.x {{cookiecutter.dev_host}}     {{cookiecutter.dev_domain}}
    x.x.x.x {{cookiecutter.qa_host}}      {{cookiecutter.qa_domain}}
    x.x.x.x {{cookiecutter.staging_host}} {{cookiecutter.staging_domain}}
    x.x.x.x {{cookiecutter.prod_host}}    {{cookiecutter.prod_domain}}
    ```
- Put this in your ``~/.ssh/config``

    ```sshconfig
    Host {{cookiecutter.dev_host}}
    User root
    ServerAliveInterval 5
    Port {{cookiecutter.dev_port}}
    {%- if cookiecutter.staging_host%}
    Host {{cookiecutter.staging_host}}
    User root
    ServerAliveInterval 5
    Port {{cookiecutter.staging_port}}
    {%-endif%}
    {%-if cookiecutter.qa_host %}
    Host {{cookiecutter.qa_host}}
    User root
    ServerAliveInterval 5
    Port {{cookiecutter.qa_port}}
    {%-endif%}
    {%-if cookiecutter.prod_host %}
    Host {{cookiecutter.prod_host}}
    User root
    ServerAliveInterval 5
    Port {{cookiecutter.prod_port}}
    {%-endif%}
    ```

## init local deploy
- see [./readme](./README.md#setupvault)

    ```sh
    .ansible/scripts/download_corpusops.sh
    .ansible/scripts/setup_ansible.sh
    :; eval "CORPUSOPS_VAULT_PASSWORD_${A_ENV_NAME}='supersecret' \
        .ansible/scripts/setup_vaults.sh"
    .ansible/scripts/call_ansible.sh -vvv .ansible/playbooks/deploy_key_setup.yml
    ```

## Install base softwares (ssh, base pkgs, editors, etc)
```sh
.ansible/scripts/call_ansible.sh -vvv .ansible/playbooks/bootstrap.yml \
    -t vars,base,tools,firewall,docker  -l "baremetals" \
    -e "{cops_vars_debug: true}"
```

## LXC
- install lxc

    ```sh
    .ansible/scripts/call_ansible.sh -l compute_nodes_lxcs \
        */*/*/corpusops.roles/playbooks/provision/lxc_compute_node/main.yml \
        -e "{cops_vars_debug: true}"
    ```
- make a ubuntu template and snapshot it

    ```sh
    export COPS_ROOT="$(pwd)/local/corpusops.bootstrap"
    r=bionic
    h=compute_nodes_lxcs
    .ansible/scripts/call_ansible.sh -vvvv \
        */*/corpusops.roles/playbooks/provision/lxc_container.yml \
        -e "{lxc_host: $h, lxc_container_name: corpusops${r}, ubuntu_release: ${r}}"
    .ansible/scripts/call_ansible.sh -vvvv \
        */*/*/*/playbooks/provision/lxc_container/snapshot.yml \
        -e "{lxc_host: $h, container: corpusops${r}, image: corpusops${r}tpl}"
    .ansible/scripts/call_ansible.sh -vvvv */*/*/lxc_stop/role.yml \
        -l $h -e "{lxc_container_name: corpusops${r}tpl}"
    ```

- create lxcs from this template

    ```sh
    export COPS_ROOT="$(pwd)/local/corpusops.bootstrap"
    h="dev_vps"
    vms="{{cookiecutter.dev_host}} {{cookiecutter.staging_host}} {{cookiecutter.qa_host}} {{cookiecutter.prod_host}}"
    set -e
    for i in $vms;do
      .ansible/scripts/call_ansible.sh -vvvv \
        $COPS_ROOT/roles/corpusops.roles/playbooks/provision/lxc_container.yml \
        -e "{lxc_host: $h, lxc_container_name: $i}"
    done
    set +e
    ```

    ```sh
    export COPS_ROOT="$(pwd)/local/corpusops.bootstrap"
    h="prod_vps"
    vms="{{cookiecutter.prod_host}}"
    set -e
    for i in $vms;do
      .ansible/scripts/call_ansible.sh -vvvv \
        $COPS_ROOT/roles/corpusops.roles/playbooks/provision/lxc_container.yml \
        -e "{lxc_host: $h, lxc_container_name: $i}"
    done
    set +e
    ```

## SSL / Letsencrypt

## Install docker everywhere
```sh
.ansible/scripts/call_ansible.sh -vvvv \
    local/*/*/corpusops.roles/services_virt_docker/role.yml
```

## Install gitlab runners
- Install runner package and service, + docker inside ci runners

    ```sh
    .ansible/scripts/call_ansible.sh -vvvv -l ci_runners \
      local/*/*/corpusops.roles/services_ci_gitlab_runner/role.yml
    ```
### Register to gitlab server each CI node runner
- ``pre_clone_script`` is suport important to workaround [gitlab#1736](https://gitlab.com/gitlab-org/gitlab-runner/issues/1736)
- you also need to adjust ``volumes``
- On your docker executor gitlabCI runner, ensure it is configured as the following

    ```sh
    lxc-attach -n <your ci runner>
    gitlab-runner register
    # - https://gitlab.com/
    # - ``<token>`` on https://{{cookiecutter.git_url}}/settings/ci_cd
    # - tags: ["{{cookiecutter.runner_tag}}"]
    # - docker
    # - corpusops/ubuntu:18.04
    vim /etc/gitlab-runner/config.toml
    # [[runners]]
    # builds_dir = "/srv/nobackup/gitlabrunner/builds"
    # cache_dir = "/cache"
    # pre_clone_script = "umask 0022"
    # [runners.docker]
    # privileged: true
    # disable_cache: false
    # volumes = ["/cache:/cache", "/run/docker.sock:/host-docker-socket/docker.sock"]
    mkdir /srv/nobackup/gitlabrunner/builds /cache -p
    service gitlab-runner restart
    ```
- On {{cookiecutter.git_url}}/settings/ci_cd / variable
    - setup ``CORPUSOPS_VAULT_PASSWORD``

## Reconfigure haproxy/msiptables (load balancer & firewall)
- do

    ```sh
    export A_ENV_NAME=staging
    # or export A_ENV_NAME=prod
    .ansible/scripts/call_ansible.sh -vvv -l baremetals_${A_ENV_NAME} \
        local/*/*/*/playbooks/provision/lxc_compute_node/main.yml \
        -t lxc_haproxy_registrations,lxc_ms_iptables_registrations
    ```

## hand delivery on dev/qa/staging/prod
- do

    ```sh
    # docker image tag to pull
    export CI_COMMIT_TAG_NAME=v2.1
    export CI_COMMIT_REF_NAME=master
    # staging or  prod
    export A_ENV_NAME=staging
    # or export A_ENV_NAME=prod
    .ansible/scripts/call_ansible.sh -vvv -l $A_ENV_NAME .ansible/playbooks/app.yml
    ```
