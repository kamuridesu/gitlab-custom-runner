FROM gitlab/gitlab-runner
RUN apt-get update && apt-get install sudo vim -y
RUN groupadd wheel
RUN usermod -a -G wheel gitlab-runner
RUN echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
COPY ./script.sh /usr/bin/start
RUN chmod +x /usr/bin/start
ENTRYPOINT [ "/usr/bin/start" ]
