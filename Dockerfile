FROM openjdk:8-jdk-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /home/appuser
ARG JAR_FILE=target/*.jar
ADD ${JAR_FILE} app.jar
RUN chown appuser:appgroup app.jar
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/home/appuser/app.jar"]
