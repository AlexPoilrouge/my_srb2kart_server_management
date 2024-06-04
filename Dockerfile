FROM archlinux:latest

COPY docker/mirrorlist /etc/pacman.d/mirrorlist
RUN chmod 644 /etc/pacman.d/mirrorlist

RUN	 pacman -Syy

RUN pacman -Syu --noconfirm --needed base-devel sudo wget python tar git ansible yq


COPY docker/*.sh /scripts/

RUN sh  /scripts/install_aur_packages.sh srb2kart-data srb2kart


RUN mkdir -p /var/kart_source


COPY config /var/kart_source/config
COPY scripts /var/kart_source/scripts
COPY web /var/kart_source/web
COPY install.sh /var/kart_source

WORKDIR /var/kart_source


EXPOSE 5029/udp

VOLUME /kart_addons

RUN mkdir -p /kart_home/.srb2kart && ln -s /kart_addons /kart_home/.srb2kart/kart_addons

RUN sh install.sh

CMD [ "sh", " /scripts/launch_kart.sh" ]
