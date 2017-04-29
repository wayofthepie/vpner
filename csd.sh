#!/usr/bin/env bash
# NOTE: This was ripped almost exactly from some gist...

# Enter your vpn host here
CSD_HOSTNAME=VPN_URL

ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]
then
    ARCH="linux_x64"
else
    ARCH="linux_i386"
fi

function fetch {
  if [[ -z ${CSD_HOSTNAME} ]]
  then
    echo "Define CSD_HOSTNAME with vpn-host in script text or export as environment. Exiting."
    exit 1
  fi
  url="https://${CSD_HOSTNAME}/CACHE/sdesktop/hostscan/$ARCH/$1"
  echo "Downloading: $FILE from $url"
  curl -s --max-time 30 $url -o $2
}

HOSTSCAN_DIR="$HOME/.cisco/hostscan"
LIB_DIR="$HOSTSCAN_DIR/lib"
BIN_DIR="$HOSTSCAN_DIR/bin"

BINS=("cscan" "cstub" "cnotify")


# parsing command line
shift

URL=
TICKET=
STUB=
GROUP=
CERTHASH=
LANGSELEN=

echo $0 $*
while [ "$1" ]; do
    if [ "$1" == "-ticket" ];   then shift; TICKET=$1; fi
    if [ "$1" == "-stub" ];     then shift; STUB=$1; fi
    if [ "$1" == "-group" ];    then shift; GROUP=$1; fi
    if [ "$1" == "-certhash" ]; then shift; CERTHASH=$1; fi
    if [ "$1" == "-url" ];      then shift; URL=$1; fi
    if [ "$1" == "-langselen" ];then shift; LANGSELEN=$1; fi
    shift
done


# creating dirs
for dir in $HOSTSCAN_DIR $LIB_DIR $BIN_DIR ; do
    if [[ ! -f $dir ]]
    then
        mkdir -p $dir
    fi
done

if [ ! -e $HOSTSCAN_DIR/manifest ]; then
  fetch "manifest" "$HOSTSCAN_DIR/manifest"
fi

# generating md5.sum with full paths from manifest
export HOSTSCAN_DIR=$HOSTSCAN_DIR
cat $HOSTSCAN_DIR/manifest | sed -r 's/\(|\)//g' | awk '{ cmd = "find $HOSTSCAN_DIR -iname " $2; while (cmd | getline line) { print $4, line; } }' > $HOSTSCAN_DIR/md5.sum

# check number of files either
MD5_LINES=`wc --lines $HOSTSCAN_DIR/md5.sum | awk '{ print $1; }'`
MANIFEST_LINES=`wc --lines $HOSTSCAN_DIR/manifest | awk '{ print $1; }'`
echo "Got $MANIFEST_LINES files in manifest, locally found $MD5_LINES"

# check md5
md5sum -c $HOSTSCAN_DIR/md5.sum
if [[ "$?" -ne "0" || "$MD5_LINES" -ne "$MANIFEST_LINES" ]]
then
    echo "Corrupted files, or whatever wrong with md5 sums, or missing some file"
    # just download every file mentioned in manifest (not ideal, but hopefully should be enough)
    FILES=( $(cat $HOSTSCAN_DIR/manifest | sed -r 's/\(|\)//g' | awk '{ print $2; }') )
    WORK_DIR=`pwd`
    TMP_DIR=`mktemp -d` && cd $TMP_DIR
    for i in ${FILES[@]} ; do
        FILE="$(basename "$i")"

        FILE_GZ=$FILE.gz
        fetch $FILE_GZ $FILE_GZ
        gunzip --verbose --decompress $FILE_GZ

        # don't know why, but my version of hostscan requires tables to be stored in libs
        echo $FILE | grep --extended-regexp --quiet --invert-match ".so|tables.dat"
        IS_LIB=$?
        if [[ "$IS_LIB" -eq "1" ]]
        then
            cp --verbose $FILE $LIB_DIR
        else
            cp --verbose $FILE $BIN_DIR
        fi

    done

    for i in ${BINS[@]} ; do
        echo "Setting excecution bit on: $BIN_DIR/$i"
        chmod u+x $BIN_DIR/$i
    done

    cd $WORK_DIR
    rm -rf $TMP_DIR
fi

# cstub doesn't care about logging options, sic!
ARGS="-log error -ticket $TICKET -stub $STUB -group $GROUP -host $URL -certhash $CERTHASH"

echo "Launching: $BIN_DIR/cstub $ARGS"
$BIN_DIR/cstub $ARGS
