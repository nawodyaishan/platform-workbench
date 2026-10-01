# KodeKloud and lab-VM paste-ins

Session-only shell snippets for disposable Linux VMs. Nothing is installed and nothing is written to disk; close the shell and it is gone. Each topic script starts with the same basic Linux block (navigation, systemd, `ip`, `man`/`info` helpers), then adds its own tool aliases, guarded so a missing tool defines nothing.

| Topic | Script | Adds |
|---|---|---|
| CKA exam | [cka-shell.sh](cka-shell.sh) | the minimal `k`, `$do`, `$now`, Vim settings (nothing else) |
| Kubernetes | [k8s/k8s-shell.sh](k8s/k8s-shell.sh) | `cka-shell.sh` plus `kg*`, `kaf`, `klf`, `kexec`, `ktop*`, `kpf`, `kns`, helm `hm*` |
| Terraform | [terraform/terraform-shell.sh](terraform/terraform-shell.sh) | `tf*` (apply/destroy still prompt) |
| AWS | [aws/aws-shell.sh](aws/aws-shell.sh) | read-only `aws*` helpers, `awsp` to switch profile |
| Ansible | [ansible/ansible-shell.sh](ansible/ansible-shell.sh) | `ap`, `apc` (check + diff), `ainv`, `alint`, vault |
| Linux | [linux/linux-shell.sh](linux/linux-shell.sh) | the basic block plus `lport`, `topm`, `topc` |

## Basic Linux block (in every script)

- `ll`, `la`, `..`, `...`, `dfh`, `duh`, `psg`, `mem`, `lsb`, `ipa`, `ipr`, `ports`, `mkcd`, `up`
- systemd: `scs`, `scf`, `scl`, `sce`; journal: `jc`, `jcf`, `jcu`, `jce`
- docs, offline: `hlp <cmd>` (builtin help, man page, or `--help`), `mg <cmd> <pattern>` (search a man page), `mopt <cmd> <flag>` (one option's entry), `mk` (`man -k`), `mf` (`man -f`), `mw` (`whereis`), `ty` (`type -a`), `inf`, `tl`
- `EDITOR=vim`, two-space YAML `VIMINIT`, case-insensitive `less`

## Copy and paste

From the Mac, copy one to the clipboard and paste into the VM's shell. Run it again for another topic; they stack.

```bash
task kk TOPIC=terraform     # cka (default) | k8s | terraform | aws | ansible | linux
make kk TOPIC=aws           # same, through the Makefile
```

On a VM that has internet and no clipboard, source it straight from this repository. Read the script first; this runs whatever the repository serves.

```bash
source <(curl -fsSL https://raw.githubusercontent.com/nawodyaishan/platform-workbench/main/kodekloud/aws/aws-shell.sh)
```

Persistent lab hosts get the full alias set from `task bootstrap`, or `task aliases | bash` without bootstrap (see [docs/config.md](../docs/config.md#aliases-without-bootstrap)).

## Rules

- Plain `alias` lines and small functions; guarded with `command -v`; no secrets, hosts or addresses.
- No auto-approve and no destructive default; cloud helpers only read.
- The basic Linux block is copied into every script because each is pasted alone. `task repo` fails if the copies differ, so edit one and copy the block to the rest.
- Names match [`config/shell/aliases.sh`](../config/shell/aliases.sh), so muscle memory carries over to the persistent hosts.
- Don't rely on these in an exam: `$do`, `$now` and the rest may not exist there.
