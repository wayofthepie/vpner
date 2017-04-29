FROM ubuntu:16.10
ENV VPN_URL default
ENV VPN_USER default
RUN apt-get update -y && apt-get install -y curl openconnect iptables
ADD csd.sh /var/tmp/
ADD init.sh /var/tmp/
CMD /var/tmp/init.sh ${VPN_URL} ${VPN_USER}
