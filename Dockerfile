FROM archlinux:latest

COPY . /var/kart_source

RUN mkdir -p /var/kart_source

WORKDIR /var/kart_source

RUN pacman -Syu --noconfirm --needed base-devel sudo wget python


RUN sh docker/install_aur_packages.sh srb2kart-data srb2kart

EXPOSE 5029/udp

VOLUME /kart_addons

RUN cp docker/values.txt values.txt && mkdir -p /kart_home/.srb2kart && ln -s /kart_addons /kart_home/.srb2kart/addons && sh install.sh

CMD [ "sh", "docker/launch_kart.sh" ]
