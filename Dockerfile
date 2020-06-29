FROM alpine AS download-extract
RUN apk update && apk add tar unzip curl && rm -rf /var/cache
WORKDIR /var/cache/
RUN curl -OL https://controlssoftware.sns.ornl.gov/css_phoebus/nightly/alarm-server.zip
RUN unzip alarm-server.zip


FROM openjdk:16-slim-buster as final
COPY --from=download-extract /var/cache/alarm-server-4.6.3/service-alarm-server-4.6.3.jar /alarm-server/service-alarm-server-4.6.3.jar
COPY --from=download-extract /var/cache/alarm-server-4.6.3/lib /alarm-server/lib
WORKDIR /alarm-server
ENTRYPOINT ["java", "-jar", "/alarm-server/service-alarm-server-4.6.3.jar"]
CMD ["-list"]
