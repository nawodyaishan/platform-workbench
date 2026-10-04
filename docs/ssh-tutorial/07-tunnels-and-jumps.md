# 7. Tunnels and jump hosts

**Level:** advanced · **Assumes:** [chapters 3 and 6](README.md) · [Back to contents](README.md)

SSH can carry any TCP traffic, not just shells. The repo doesn't configure tunnels, because Tailscale already gives every host direct reachability. But in a lab you regularly need to reach something that isn't on the tailnet: a web UI bound to `localhost`, a VM behind the Proxmox host, or a service on a private bridge. Everything here builds on the aliases and multiplexing from earlier chapters.

## Local forwarding `-L`: bring a remote port to you

"Connections to port A on **my** machine go to host:port B as seen **from the server**."

```bash
mac$ ssh -N -L 8080:localhost:80 dev-01
```

Open `http://localhost:8080` on the Mac and you're talking to port 80 on `dev-01`, even if that service listens only on the VM's loopback address.

- `-N` means don't run a remote command, just hold the tunnel. Stop it with `Ctrl-C`.
- The middle part is resolved **on the server**, so `localhost` means the VM itself. `-L 8443:192.0.2.30:443 dev-01` reaches another machine that only `dev-01` can see.
- Local forwards bind to `127.0.0.1` by default, so other machines on your network can't use them.

Typical lab uses: a Kubernetes dashboard or a `kubectl port-forward` running on the VM, Prometheus or Grafana UIs, or a database admin port you don't want exposed.

## Remote forwarding `-R`: expose your port to the server

The reverse direction: "connections to port A on the **server** come back to host:port B as seen **from my machine**."

```bash
mac$ ssh -N -R 9000:localhost:3000 dev-01
```

On `dev-01`, `curl localhost:9000` reaches the dev server running on your Mac's port 3000. This is useful for testing a webhook or letting a lab cluster pull from a registry on your laptop. It binds to the server's loopback address unless the server's `GatewayPorts` allows otherwise, and that default is what you want.

## Dynamic forwarding `-D`: a SOCKS proxy

```bash
mac$ ssh -N -D 1080 dev-01
```

This opens a SOCKS5 proxy on `localhost:1080`. Point a browser (or `curl --socks5-hostname localhost:1080 …`) at it, and its traffic leaves from `dev-01`. Every internal web UI in the lab then works by its internal name, with no per-port tunnels.

## Jump hosts with `ProxyJump`

Suppose VMs on the Proxmox host's internal bridge aren't on the tailnet, but `proxmox` is. Reach them **through** it:

```bash
mac$ ssh -J proxmox alice@192.0.2.40
```

The connection to `192.0.2.40` is **end-to-end encrypted from your Mac**. The jump host only relays bytes. It never sees your keys or your agent, which is why `ProxyJump` is the safe replacement for "SSH into A, then SSH from A to B" with agent forwarding ([chapter 6](06-security.md)).

## Put it in config, keep it private

Tunnels and jumps that you use repeatedly belong in config, and because they involve addresses and personal choices, they go in your **private** `~/.ssh/config.d/10-hosts.local.conf`, not the shared `workbench.conf`:

```sshconfig
# Internal VM behind the hypervisor
Host lab-internal
    HostName 192.0.2.40
    User alice
    ProxyJump proxmox

# Always tunnel Grafana when connecting with this alias
Host dev-01-grafana
    HostName dev-01
    LocalForward 3000 localhost:3000
    SessionType none
```

Now `ssh lab-internal` hops through the Proxmox host automatically, using `proxmox`'s own alias settings (user, multiplexing, keepalives) for the first leg. Check the result with `ssh -G lab-internal | grep -E '^(hostname|user|proxyjump) '`.

The second alias matches `Host dev-01-grafana`, not `dev-01`, so it doesn't inherit the lab block's multiplexing. Its tunnel stays independent of your normal sessions. `SessionType none` is the config form of `-N` (OpenSSH 8.7 and later). Remove it if your client is older, and pass `-N` instead.

## Forwarding and multiplexing

With `ControlMaster` on ([chapter 4](04-sessions.md)), forwards requested when the master opened live as long as the master. You can add or remove forwards on a running master without reconnecting:

```bash
mac$ ssh -O forward -L 8080:localhost:80 dev-01
mac$ ssh -O cancel  -L 8080:localhost:80 dev-01
```

If a port seems stuck open after you "closed" a tunnel, the master is still holding it. Run `ssh -O exit dev-01`.

## Exercises

1. On `dev-01`, start a throwaway web server bound to loopback: `python3 -m http.server 8000 --bind 127.0.0.1`. From the Mac, forward it with `-L 8000:localhost:8000` and open it in a browser.
2. Reverse it: run `python3 -m http.server 3000` on the Mac, forward with `-R 9000:localhost:3000`, and `curl localhost:9000` on the VM.
3. Add a `ProxyJump` alias to your local file for a VM that's reachable only from another host, and confirm it with `ssh -G`.
4. Start a SOCKS proxy with `-D 1080` and fetch a page through it with `curl --socks5-hostname localhost:1080`.

**Next:** [8. Troubleshooting](08-troubleshooting.md)
