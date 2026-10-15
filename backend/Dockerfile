FROM dart:3.13.5-sdk AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get --enforce-lockfile
COPY . .
RUN dart build cli --target bin/server.dart --output /app/compiled

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libstdc++6 && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 semob && useradd --uid 10001 --gid semob --create-home semob \
    && mkdir -p /app/data && chown -R semob:semob /app
WORKDIR /app
COPY --from=build --chown=semob:semob /app/compiled/bundle/ /app/
COPY --from=build --chown=semob:semob /app/assets/ /app/assets/
ENV SEMOB_HOST=0.0.0.0 SEMOB_PORT=8081
USER semob
EXPOSE 8081
CMD ["/app/bin/server"]
