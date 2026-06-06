FROM ubuntu:latest
RUN apt-get update && apt-get install -y --no-install-recommends tor obfs4proxy netcat-openbsd wget && rm -rf /var/lib/apt/lists/*
COPY torrc /etc/tor/torrc
EXPOSE 9050
USER debian-tor
CMD ["tor", "-f", "/etc/tor/torrc"]
