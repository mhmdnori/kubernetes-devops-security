FROM alpine:3.20

RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache openjdk17-jdk && \
    addgroup -S appgroup && adduser -S appuser -G appgroup && \
    rm -rf /var/cache/apk/*

WORKDIR /home/appuser
COPY target/*.jar app.jar
RUN chown appuser:appgroup app.jar
ENV JAVA_TOOL_OPTIONS="--add-opens=java.base/java.io=ALL-UNNAMED"
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/home/appuser/app.jar"]