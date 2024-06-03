
# About

This is the stuff that materialize my server-side install of *SRB2 Kart* and/or *Dr Robotnik's Ring Racers*
published by [Kart Krew Dev](https://github.com/KartKrewDev).

# Install


## Ansible

Install is now managed with Ansible.

All the ansible scripts and config is found in `config/ansible`.
- The ansible playbook is `config/ansible/playbook.yaml`.
- The core elements are setup using the values in `config/ansible/variables.yaml`. This files has to be edited according to the desired install.
- A file `config/ansible/inventory.yaml` has to be written according to the install target (basic *Ansible* inventory file to define "*hosts*" nodes).

## with Makefile

A *makefile* is provided along in `config/ansible`.

### remote install

After editing `config/ansible/variables.yaml` accordingly, and creating appropriate `config/ansible/inventory.yaml`,
an install can be triggered with:
```bash
cd config/ansible
make remote_install
```

### local install

Make file also provided a `local_install` target, but using, from the project's rootdir,
the `install.sh` script should do the trick:
```bash
./install.sh
```


## Tests

### Ansible install test

The ansible install can also be tested using the `config/ansible/makefile` that uses docker for testing.
```bash
cd config/ansible

# build the docker test image
make build_docker
# run the docker container
make run_docker
# test the install of said container
make ansible_test
# check the container's inside by yourself
make exec_bash_container
# once you're done, stop the container
make stop_container
```

### Racer test

The main `Dockerfile` run's the Racer server in a container.
Just use it as a regular docker file:
```bash
docker build -t my_racer_server .
docker run my_racer_server
```

