from ubuntu:latest

ENV TZ=Europe/Minsk
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && apt-get -q -y install locales sudo

RUN apt-get update && apt-get -q -y install libssl1.0.0 libusb-1.0-0 libbluetooth3 \
  libssl-doc- libusb-1.0-doc- manpages- manpages-dev-

RUN apt-get update && apt-get -q -y install openssl liblua5.2-0 psmisc \
  autotools-dev- binutils- build-essential- bzip2- cpp- cpp-5- dpkg-dev- fakeroot- \
  manpages- manpages-dev-

RUN apt-get update && apt-get -q -y install sqlite3 libqt5websockets5 net-tools iproute2 \
  qttranslations5-l10n- xdg-user-dirs- xml-core- dbus-

RUN apt-get update && apt install -y netcat cpipe gnuplot sysstat python3-pip docker.io
RUN apt-get update && apt install -y python3-numpy python3-scipy python3-matplotlib 

RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

ENV LC_ALL en_US.UTF-8

RUN chmod u+s /sbin/ifconfig /sbin/ip && mkdir /home/developer

COPY entrypoint.sh /usr/bin/

ENTRYPOINT ["/bin/bash", "-e", "/usr/bin/entrypoint.sh"]
