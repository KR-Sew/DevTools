# Use an official Alpine as a parent image
FROM alpine:3.18

# Set environment variables
ENV SONAR_VERSION=9.9.0.65466
ENV SONARQUBE_HOME=/opt/sonarqube
ENV PATH=${SONARQUBE_HOME}/bin:$PATH

# Install dependencies
RUN apk update && \
    apk add --no-cache \
    openjdk11-jdk \
    wget \
    unzip \
    bash

# Create a sonarqube user
RUN addgroup -S sonarqube && adduser -S -G sonarqube sonarqube

# Download and unzip SonarQube
RUN wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip -O /tmp/sonarqube.zip && \
    unzip /tmp/sonarqube.zip -d /opt && \
    mv /opt/sonarqube-${SONAR_VERSION} ${SONARQUBE_HOME} && \
    rm /tmp/sonarqube.zip

# Change ownership to the sonarqube user
RUN chown -R sonarqube:sonarqube ${SONARQUBE_HOME}

# Switch to the sonarqube user
USER sonarqube

# Expose the SonarQube port
EXPOSE 9000

# Run SonarQube
CMD ["sonar.sh", "console"]
