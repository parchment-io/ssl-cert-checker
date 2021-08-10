## ssl-cert-checker

This project is a standalone web service that takes a list of configured hosts to connect to and checks them on an interval for expiration. The resulting metrics are available via the `/metrics` endpoint that Prometheus can scrape.

#### Configuring

ssl-cert-checker will connect to a list of hosts specified by the `CHECK_HOSTS` environment variable. This var is expected to be a comma-delimited string of hostname and port pairs themselves delimited by a colon. e.g. `example.com:443`

Configured hosts will be checked on start-up and every interval thereafter specified by the `CHECK_INTERVAL` environment variable. This var is a duration string, e.g. `1d`, `3h`, etc.

The listening port can be specified with the `LISTEN_PORT` environment variable.

#### Endpoints

Just like most other services that provide Prometheus metrics, just hit the endpoint. Using the default port, it would be:

http://localhost:3000/metrics

There is also a health endpoint.

http://localhost:3000/healthz

#### Running the Docker image

To run the service on the default port, use:

```
docker run -it -e CHECK_HOSTS=example.com:443 \
               -e CHECK_INTERVAL=1d \
               -p 3000:3000 \
               ghcr.io/parchment-io/ssl-cert-checker:1.0.0
```

#### Running locally

Simply install the required gems and run app/server.rb:

```
bundle install
CHECK_HOSTS=example.com:443 bundle exec app/server.rb
```
