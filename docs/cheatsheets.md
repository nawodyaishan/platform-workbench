# Lab cheatsheets

These are inspect-first command references for the Kubernetes, Linux and Terraform lab work. Aliases and functions refer to [config/shell/aliases.sh](../config/shell/aliases.sh) and [functions.sh](../config/shell/functions.sh). Each alias exists only when its tool is installed.

## Kubernetes

### Where am I?

Check this before any change, especially on shared or exam clusters.

```bash
hostname
kubectl config current-context                                   # kctx
kubectl config get-contexts                                      # kctxs
kubectl config use-context <context>
kubectl config view --minify -o 'jsonpath={..namespace}'
kns <namespace>        # set the namespace on the current context
```

### Inspect before mutating

```bash
kubectl get all -n <ns>
kubectl get pods -n <ns> -o wide                                 # kgp
kubectl get events -n <ns> --sort-by=.lastTimestamp
kubectl describe pod <pod> -n <ns>                               # kdesc pod <pod>
kubectl logs <pod> -n <ns> [-c <container>] [--previous]         # klogs
kubectl get svc,endpointslices -n <ns>                           # kgs
kubectl rollout status deploy/<name> -n <ns>
kubectl rollout history deploy/<name> -n <ns>
kubectl get nodes -o wide                                        # kgn
kubectl describe node <node>      # conditions: MemoryPressure, DiskPressure, PIDPressure
```

A failing pod gets the same order every time: context and namespace, pods and events, `describe`, logs (including `--previous`), services and endpoints, deployments and replicasets, then node pressure. Use `kubectl exec -it <pod> -- sh` (`kexec`) only when inspection is not enough, and verify after every fix.

### Throwaway debug pod

```bash
kubectl run debug-shell --image=busybox --rm -it --restart=Never -- sh
kubectl debug -it <pod> --image=busybox --target=<container>   # ephemeral container
```

### Generate, don't hand-write

```bash
kubectl create deploy web --image=nginx --replicas=2 --dry-run=client -o yaml > web.yaml
kubectl expose deploy web --port=80 --dry-run=client -o yaml > web-svc.yaml
kubectl apply -f web.yaml                                        # kaf
kubectl delete -f web.yaml                                       # kdf
```

On a KodeKloud node, the [pasted snippet](kodekloud.md) shortens these to `$do` and `$now`.

### JSONPath

```bash
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
kubectl get pods --sort-by=.metadata.creationTimestamp
```

### Aliases

| Alias | Command |
|---|---|
| `k` | `kubectl` (with completion) |
| `kgp` / `kgs` / `kgd` / `kgn` / `kgns` | `kubectl get pods` / `svc` / `deploy` / `nodes` / `ns` |
| `kaf` / `kdf` | `kubectl apply -f` / `kubectl delete -f` |
| `kdesc` | `kubectl describe` |
| `klogs` | `kubectl logs` |
| `kexec` | `kubectl exec -it` |
| `kctx` / `kctxs` | current context / all contexts |

## Linux

### Processes and ports

```bash
ps aux | grep -i <name>
pgrep -fl <name>
top                                    # or htop
ports                                  # listening sockets (ss -tulpn, lsof on macOS)
sudo ss -tlnp | grep :<port>
sudo lsof -i :<port>
kill <pid>                             # SIGTERM first; kill -9 only if it will not exit
```

### Services and logs

```bash
systemctl status <unit>
systemctl list-units --failed
journalctl -u <unit> -n 50 --no-pager
journalctl -u <unit> -f
journalctl -b -p err                   # errors since boot
```

### Disk

```bash
df -h
df -i                                  # "disk full" with free space means inodes
lsblk -f
sudo du -xh --max-depth=1 / | sort -rh | head -20
sudo find / -xdev -size +100M -type f 2>/dev/null
```

### Network

```bash
ip -br addr
ip route
ping -c 3 <host>
dig <name>                             # nslookup <name> where dig is missing
curl -sSI <url>
tracepath <host>                       # or mtr -rw <host>
sudo tcpdump -ni any port <port>
tailscale status
```

### Permissions and SELinux (RHEL)

```bash
ls -la <path>; stat <path>
id; groups
namei -l <path>                        # permissions along the whole path
sudo find / -xdev -perm -4000 -type f 2>/dev/null   # setuid binaries
getenforce
ls -Z <path>
sudo ausearch -m avc -ts recent
sudo restorecon -Rv <path>
sudo firewall-cmd --list-all
```

## Terraform

### The loop

```bash
terraform init          # tfi
terraform fmt           # tff  (add -recursive for nested modules)
terraform validate      # tfv
terraform plan          # tfp  - read it before applying
terraform apply         # tfa  - prompts for approval
terraform output        # tfo
terraform destroy       # tfd  - destructive; prompts for approval
```

`tf` is `terraform`. Use `-auto-approve` only in a disposable lab with a clear cleanup path.

### State

```bash
terraform state list
terraform state show <address>
terraform show
terraform console
terraform state rm <address>    # forgets the resource without destroying it - debugging only
```

State maps configuration to real infrastructure and can contain secrets. State files, `*.tfvars` and `.terraform/` are ignored by this repository's `.gitignore`, and `task secrets` also rejects state and tfvars files.

### Common errors

| Symptom | First step |
|---|---|
| Provider or module not installed | `terraform init` (`-upgrade` after changing version constraints) |
| Formatting drift in CI | `terraform fmt -recursive` |
| Invalid or unsupported argument | `terraform validate`, then check the provider docs for the pinned version |
| State lock held | Confirm nobody else is running, then `terraform force-unlock <id>` |
