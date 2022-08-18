# best practice to not use latest tag, drawback is that we need to ensure particular tag compatibility
# and not forget to update tag when migrating to new container major release
FROM ubuntu:jammy

# minimize the number of layers https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#apt-get
RUN apt-get update && apt-get install -y \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd wheel
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
RUN useradd -G wheel -m user

# best practice to use absolute pathes https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#workdir
COPY --chown=user:user . /home/user/MagiskOnWSALocal

# in case you decide to remove executable bit in VCS
RUN chmod +x /home/user/MagiskOnWSALocal/scripts/run.sh

USER user

RUN /home/user/MagiskOnWSALocal/scripts/run.sh InstallDependencies
RUN mkdir -p /home/user/MagiskOnWSALocal/output

WORKDIR /home/user/MagiskOnWSALocal
VOLUME ["/home/user/MagiskOnWSALocal/output"]
CMD ["/usr/bin/env", "sh", "-c", "sudo chown -R user:user /home/user/MagiskOnWSALocal/output && exec /home/user/MagiskOnWSALocal/scripts/run.sh"]
