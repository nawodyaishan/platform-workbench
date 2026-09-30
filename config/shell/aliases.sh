# shellcheck shell=sh
# platform-workbench canonical aliases. Sourced by bash and zsh (see bashrc / zshrc).
#
# Rules: plain `alias` lines only; optional tools are guarded with `command -v`;
# never shadow a standard command with different behaviour; never auto-approve
# anything destructive; no paths, hosts or secrets. Functions live in functions.sh.
# kodekloud/cka-shell.sh is the only other place aliases are defined (paste-in).

# --- General ---------------------------------------------------------------------
alias c='clear'
alias h='history'
alias ll='ls -laF'

# --- Git -------------------------------------------------------------------------
if command -v git >/dev/null 2>&1; then
  alias gs='git status --short'
  alias ga='git add'
  alias gc='git commit'
  alias gp='git push'
  alias gl='git pull'
  alias gd='git diff'
fi

# --- Kubernetes (same set as the exam shell so muscle memory carries over) -------
if command -v kubectl >/dev/null 2>&1; then
  alias k='kubectl'
  alias kgp='kubectl get pods'
  alias kgs='kubectl get svc'
  alias kgd='kubectl get deploy'
  alias kgn='kubectl get nodes'
  alias kgns='kubectl get ns'
  alias kaf='kubectl apply -f'
  alias kdf='kubectl delete -f'
  alias kdesc='kubectl describe'
  alias klogs='kubectl logs'
  alias kexec='kubectl exec -it'
  alias kctx='kubectl config current-context'
  alias kctxs='kubectl config get-contexts'
fi

# --- Terraform (apply/destroy prompt for confirmation, on purpose) ---------------
if command -v terraform >/dev/null 2>&1; then
  alias tf='terraform'
  alias tfi='terraform init'
  alias tff='terraform fmt'
  alias tfv='terraform validate'
  alias tfp='terraform plan'
  alias tfa='terraform apply'
  alias tfd='terraform destroy'
  alias tfo='terraform output'
fi

# --- tmux ------------------------------------------------------------------------
if command -v tmux >/dev/null 2>&1; then
  alias tls='tmux ls'
  alias ta='tmux attach -t'
  alias tn='tmux new -s'
fi
