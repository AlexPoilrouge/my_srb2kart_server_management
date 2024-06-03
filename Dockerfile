FROM archlinux:latest

COPY config/ansible/docker_test/mirrorlist /etc/pacman.d/mirrorlist

RUN	 pacman -Syy

COPY . /var/kart_source

RUN mkdir -p /var/kart_source

WORKDIR /var/kart_source

RUN pacman -Syu --noconfirm --needed base-devel sudo wget python tar git ansible


RUN sh docker/install_aur_packages.sh srb2kart-data srb2kart

EXPOSE 5029/udp

VOLUME /kart_addons

RUN mkdir -p /kart_home/.srb2kart && ln -s /kart_addons /kart_home/.srb2kart/kart_addons

RUN run sh intall.sh

CMD [ "sh", "docker/launch_kart.sh" ]
