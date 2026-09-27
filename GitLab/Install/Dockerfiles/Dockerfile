FROM debian:12.5-slim

# Set environment variables
ENV GITLAB_HOME /home/git
ENV GITLAB_LOG /var/log/gitlab
ENV GITLAB_CONF /etc/gitlab

# Install necessary packages
RUN apt-get update && apt-get install -y \
    curl \
    openssh-server \
    ca-certificates \
    tzdata \
    perl \
    postfix

# Install GitLab
RUN curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
RUN apt-get install -y gitlab-ce

# Configure GitLab to use an external database
COPY gitlab.rb /etc/gitlab/gitlab.rb

# Expose necessary ports
EXPOSE 80 443 22

# Start GitLab
CMD (/opt/gitlab/embedded/bin/runsvdir-start &) && gitlab-ctl reconfigure && tail -f /var/log/gitlab/gitlab-rails/production.log
