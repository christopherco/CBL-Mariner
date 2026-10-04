FROM localhost/azldev-runner

# Match the scenario CI's primary mock group without replacing pinned azldev.
# Reference: azure-linux-dev-tools@96267ffd9a270abe34aa99596299e3dbd9c6fc6e.
USER builduser:mock
COPY --chmod=755 copilot-ci-entrypoint.sh /usr/local/bin/copilot-ci-entrypoint
ENTRYPOINT ["/usr/local/bin/copilot-ci-entrypoint"]
