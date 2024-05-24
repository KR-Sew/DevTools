# Use Debian as the base image
FROM debian:latest

# Set environment variables
ENV GITLAB_HOME /home/git
ENV GITLAB_USER git
ENV GITLAB_REPO https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh

# Update and install dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    openssh-server \
    ca-certificates \
    tzdata \
    perl \
    && apt-get clean

# Add GitLab package repository and install GitLab
RUN curl -s ${GITLAB_REPO} | bash && \
    apt-get update && \
    apt-get install -y gitlab-ce && \
    apt-get clean

# Expose HTTP and SSH ports
EXPOSE 80 443 22

# Configure and start GitLab
RUN gitlab-ctl reconfigure

# Start GitLab
CMD ["gitlab-ctl", "start"]

# Healthcheck to ensure GitLab is running
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1
