# Clawk init support for rootless Podman and Kind

Update `clawk-init` to provide the boot-time foundation for rootless Podman and Kind, including working resource limits. Most changes belong in [`init_main.go.in`](https://github.com/clawkwork/clawk/blob/main/internal/agentembed/init_main.go.in), with companion changes in session startup and Podman configuration.

1. **Ensure subordinate user IDs.** After creating or reconciling the manifest user, ensure at least 65,536 subordinate UIDs and GIDs. Preserve existing valid assignments, avoid overlaps, and handle existing users as well as newly created users. Make updates atomic and idempotent.

2. **Prepare devices and runtime directories.** Set `/dev/net/tun` to `0666` when present. Create `/run/user/<uid>` owned by the user with mode `0700`, and provide `XDG_RUNTIME_DIR` to their sessions. Complete setup before starting agent services.

3. **Create a delegated cgroup v2 hierarchy.** Enable available controllers through the ancestors, including CPU, memory, and PIDs. Create a per-user subtree with separate leaves for sessions and container workloads. Keep intermediate controller-distributing cgroups empty. Grant the user ownership of the delegated directory and appropriate delegation files; retain root ownership above that boundary and over its resource limits. Follow the kernel's [delegation and hierarchy rules](https://docs.kernel.org/admin-guide/cgroup-v2.html#delegation).

4. **Place sessions inside that hierarchy.** The root-owned PTY agent must start user processes in the session leaf before handing control to them. Descendants then inherit membership. This requires a companion change in `main.go.in`; creating directories in init alone is insufficient.

5. **Connect Podman to the delegated parent.** Generate a Clawk-owned, per-user configuration drop-in selecting `cgroupfs` and the explicit delegated parent, preserving unrelated image/user settings. Apply it after home mounts and manifest files. Keep rootful Podman's configuration separate. Podman's [rootless cgroupfs implementation](https://github.com/containers/podman/blob/v5.8.7/libpod/container_internal_linux.go#L406) needs that explicit parent.

6. **Apply workload settings at boot.** For supported Kind workloads, raise inotify limits to at least 524,288 watches and 512 instances, preserving higher values. Set an appropriate container PID limit through Podman configuration. Validate networking and controller availability, and report incomplete setup clearly. These follow [Kind's requirements](https://kind.sigs.k8s.io/docs/user/rootless/).

The mapping-helper privilege issue remains a separate image-import investigation: verify that `newuidmap`/`newgidmap` retain their intended capabilities or setuid permissions through export and import.

Acceptance should require:

- Repeated initialization, existing users, UID reconciliation, and allocation collisions work correctly.
- Rootless Podman pulls, builds, and runs containers without manual repairs.
- CPU, memory, and PID limits have the requested values **and enforce them**.
- Kind reaches node readiness and runs workloads with working DNS and service connectivity.
- Those checks pass again after a cold boot, without our image-specific ID assignments or Podman wrapper.

Full rootless Kind support should be claimed only after that integration test passes; ordinary container startup already proved insufficient.
