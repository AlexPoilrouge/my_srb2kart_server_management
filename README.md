
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

### SRB2Kart + RingRacers

You can install both, or only one of them, depending on the values in `config/ansible/variables.yaml`.

For instance, this example only installs *Sonic Robo Blast 2 Kart*, but you can also install
*Dr. Robotnik's Ring Racers* by just adding the following yaml item to the `.racers` list:
```yaml
  - name: RingRacers
    dirname: .ringracers
    aur_pkg: ringracers
    exe: /usr/bin/ringracers
    launch_args: -bandwidth 2000000 -room 33
    addr: 127.0.0.1
```

#### Important notes:

Make sure the config don't overlap, and the servers don't run on same port (tweak
the `.racers.[].launch_args` value).

Also, both of the server must have a ***server config*** template.
For SRB2Kart and RingRacers, respectively:
- `config/ansible/templates/my_server_config.cfg.SRB2Kart.j2`
- `config/ansible/templates/my_server_config.cfg.RingRacers.j2`


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

