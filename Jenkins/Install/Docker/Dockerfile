# Use the official Debian image as the base image
FROM debian:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV JENKINS_HOME=/var/jenkins_home

# Install Java (required by Jenkins), wget, and curl
RUN apt-get update && \
    apt-get install -y openjdk-11-jdk wget curl gnupg && \
    rm -rf /var/lib/apt/lists/*

# Add Jenkins key and source list
RUN curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add - && \
    echo "deb http://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list

# Install Jenkins
RUN apt-get update && \
    apt-get install -y jenkins && \
    rm -rf /var/lib/apt/lists/*

# Install PostgreSQL JDBC Driver
RUN wget -O /usr/share/jenkins/ref/postgresql.jar https://jdbc.postgresql.org/download/postgresql-42.2.18.jar

# Expose Jenkins port
EXPOSE 8080

# Expose the volume
VOLUME /var/jenkins_home

# Set the default user to 'jenkins'
USER jenkins

# Start Jenkins
CMD ["java", "-Djava.awt.headless=true", "-jar", "/usr/share/jenkins/jenkins.war"]
