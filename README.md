# Vpner
This repository contains

  * The `csd` script necessary to connect to a VPN which expects an AnyConnect client.
  * Instructions on how to get openconnect to work using this `csd` script.
  * A `docker`image to wrap it all up.

# Openconnect On The Host
If you just want to run openconnect, replacing your use of AnyConnect you first need to
update `CSD_HOSTNAME` in [csd.sh](csd.sh). The value of
`CSD_HOSTNAME` is `VPN_URL`, replace this with your VPN's url.
```
CSD_HOSTNAME=my-vpn.com
```
Now, run open connect setting `--csd-user` to the user _on your system_ which will run
the CSD script, `${VPN_USER}` to the user you want to login to the VPN with and `${VPN_URL}`
to the URL of the VPN you are logging into.
```
$ sudo openconnect -u${VPN_USER} ${VPN_URL} --csd-user=root --csd-wrapper=/var/tmp/csd.sh
```

# Openconnect In Docker
It is also possible to run openconnect inside a docker container and route traffic from the
host through the container. To do this first build this repo's image.

```
$ docker build --tag vpner .
```

Now run a container as follows:

```
$ docker run -ti --name vpner -e VPN_URL=${VPN_URL} -e VPN_USER=${VPN_USER} --privileged --cap-add=ALL vpner
```

This will run the [init.sh](init.sh) script which sets up forwarding via `iptables` within
the container and starts `openconnect` as outlined above. The first time this is run it will
have to pull down a bunch of libs and executables so may take a minute or so. The first
prompt will be a prompt for _PASSCODE_ you can just hit return here and then it will prompt
for your correct credentials. Once you are logged in, you can enter the container via
`docker exec -ti vpner bash` and ping a host on your vpn.

## Host Through Container Routing
The container will now allow forwading through it and then along the `tun` device that `openconnect`
sets up. The last thing you need to do to get the host access to the VPN is to set up a
route through the container. Run the following to get the IP of the container:

```
$ docker inspect --format '{{ .NetworkSettings.IPAddress }}' vpner
172.17.0.2
```
Finally, set up a route:

```
$ sudo ip route add 10.0.0.0/8 via 172.17.0.2
```
