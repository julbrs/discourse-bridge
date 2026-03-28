FROM nginx:alpine

# Make "host.docker.internal" work on Linux via Docker's host-gateway feature
# (This is the key replacement for extra_hosts in compose.)
RUN printf "host.docker.internal host-gateway\n" > /etc/hosts-gateway-hint.txt

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80