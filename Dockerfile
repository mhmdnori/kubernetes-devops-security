FROM openjdk:17-jdk-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /home/appuser
COPY target/*.jar app.jar
RUN chown appuser:appgroup app.jar
ENV JAVA_TOOL_OPTIONS --add-opens=java.base/java.io=ALL-UNNAMED
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/home/appuser/app.jar"]