# T0: copy a target image's filesystem into a helper so it can be inspected
# without executing anything from the target (works for distroless images).
ARG TARGET_IMAGE
ARG HELPER_IMAGE
FROM ${TARGET_IMAGE} AS target
FROM ${HELPER_IMAGE}
COPY --from=target / /rootfs
