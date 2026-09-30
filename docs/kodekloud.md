# KodeKloud and disposable lab nodes

Disposable nodes get nothing installed. Run `task kk` on the Mac to copy [kodekloud/cka-shell.sh](../kodekloud/cka-shell.sh) to the clipboard, then paste it into the lab's Bash shell. It lasts only for the current shell, so repeat it on each new node.

It provides:

- `k` for `kubectl`, with completion
- `EDITOR`/`KUBE_EDITOR=vim`
- `$do` (`--dry-run=client -o yaml`) and `$now` (`--force --grace-period=0`)
- a minimal `VIMINIT` with two-space YAML indentation
- the current hostname and kubectl context printed, so you know where you are

`k`, its completion and the Vim editor settings behave the same as on the persistent labs, so muscle memory carries over. `$do` and `$now` exist only in this snippet. Don't rely on the snippet in an exam. Always check host, context and namespace before changing resources. See [cheatsheets.md](cheatsheets.md) for the inspect-first command flow.
