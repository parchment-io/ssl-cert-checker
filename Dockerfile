FROM ruby:2.7.3-slim-buster
COPY app /app
COPY Gemfile* /
RUN apt-get update && apt upgrade -y && \
  apt-get install --no-install-recommends -y build-essential curl && rm -fr /var/lib/apt/lists/* && \
  gem install bundler:2.2.15 && \
  bundle config set --local without 'dev' && \
  bundle install && \
  apt-get remove -y build-essential && \
  apt-get autoremove -y

ENV APP_ENV=production
ENV LISTEN_PORT=3000
EXPOSE $LISTEN_PORT
HEALTHCHECK --interval=2m CMD curl -f http://localhost:${LISTEN_PORT}/healthz || exit 1
ENTRYPOINT ["bundle", "exec", "/app/server.rb"]
