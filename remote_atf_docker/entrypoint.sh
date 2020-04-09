#!/bin/bash

# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or
# fallback

USER_ID=${LOCAL_USER_ID:-9001}

useradd --shell /bin/bash -u $USER_ID -o -c "" developer
usermod -aG docker developer
sudo chmod 666 /var/run/docker.sock
echo "developer ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

chown developer /home/developer
chgrp developer /home/developer

export HOME=/home/developer
export LANG=en_US.UTF-8

echo "Remote adapter server available by following ip adresses : "
ip addr  | grep -E "inet " | tr -s " " | cut -d ' ' -f 3| cut -d '/' -f 1

ls /home/developer

echo "SDL bin dir : /home/developer/sdlbin"; ls /home/developer/sdlbin
echo "ATF bin dir : /home/developer/atfbin"; ls /home/developer/atfbin
echo "Third party  /home/developer/thirdparty"; ls /home/developer/thirdparty

cd /home/developer/atfbin/RemoteTestingAdapterServer

echo "Third party contents"
LIB="/home/developer/thirdparty/lib/"
LIB64="/home/developer/thirdparty/x86_64/lib/"

sudo LD_LIBRARY_PATH="$LIB:$LIB64:." -u developer "./RemoteTestingAdapterServer"

