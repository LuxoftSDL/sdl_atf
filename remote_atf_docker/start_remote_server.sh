PATH_TO_SDLBIN=$1
PATH_TO_ATFBIN=$2
PATH_TO_THIRDPARTY=$3

if [ -z "$PATH_TO_SDLBIN" ]; then
       echo "Path to SDL binaries is not defined as 1st argument"
       exit 1;
fi

if [ -z "$PATH_TO_ATFBIN" ]; then
       echo "Path to ATF binaries is not defined as 2nd argument"
       exit 1;
fi

if [ -z "$PATH_TO_THIRDPARTY" ]; then
       echo "Path to 3rd party libraries is not defined as 3rd argument"
       exit 1;
fi

CONTAINER_NAME=remote_sdl
IMAGE_NAME=remote_atf_server
MEMORY_CONSTRAINS=4G
CPUS=2
docker rm $CONTAINER_NAME

echo $1 $2 $3
docker run -e LOCAL_USER_ID=$UID \
       -e CONTAINER_NAME=$CONTAINER_NAME\
       -e LOCAL_USER_ID=$(id -u)\
       --net=host\
       --name=$CONTAINER_NAME\
       -v /var/run/docker.sock:/var/run/docker.sock\
       -v $PATH_TO_SDLBIN:/home/developer/sdlbin\
       -v $PATH_TO_ATFBIN:/home/developer/atfbin\
       -v $PATH_TO_THIRDPARTY:/home/developer/thirdparty\
       -m=$MEMORY_CONSTRAINS\
       -it $IMAGE_NAME
