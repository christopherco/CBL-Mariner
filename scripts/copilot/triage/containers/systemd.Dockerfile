# T2: published Azure Linux container plus systemd as PID 1.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
ARG PACKAGES=""
RUN dnf -y install systemd ${PACKAGES} && dnf clean all
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/sbin/init"]
