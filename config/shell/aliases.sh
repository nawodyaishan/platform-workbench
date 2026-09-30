# shellcheck shell=sh
# platform-workbench canonical aliases. Sourced by bash and zsh (see bashrc / zshrc).
#
# Rules: plain `alias` lines only; optional tools are guarded with `command -v`;
# never shadow a standard command with different behaviour; never auto-approve
# anything destructive; no paths, hosts or secrets. Functions live in functions.sh.
# Names shared with oh-my-zsh plugins keep the oh-my-zsh meaning, so bash and zsh agree.
# kodekloud/cka-shell.sh is the only other place aliases are defined (paste-in).

# --- General ---------------------------------------------------------------------
alias c='clear'
alias cl='clear'
alias h='history'
alias ll='ls -laF'
alias la='ls -lAh'
alias ..='cd ..'
alias dfh='df -h'
alias duh='du -sh'

# --- Task and make ---------------------------------------------------------------
if command -v task >/dev/null 2>&1; then
  alias t='task'
fi
if command -v make >/dev/null 2>&1; then
  alias m='make'
  alias mr='make run'
  alias ml='make lint'
  alias mb='make build'
fi

# --- Git -------------------------------------------------------------------------
if command -v git >/dev/null 2>&1; then
  alias gs='git status --short'
  alias gst='git status'
  alias ga='git add'
  alias gc='git commit'
  alias gp='git push'
  alias gl='git pull'
  alias gf='git fetch'
  alias gd='git diff'
  alias gds='git diff --staged'
  alias gb='git branch'
  alias gco='git checkout'
  alias gsw='git switch'
  alias gswc='git switch --create'
  alias gcl='git clone --recurse-submodules'
  alias glog='git log --oneline --decorate --graph'
  alias gstp='git stash pop'
fi
if command -v lazygit >/dev/null 2>&1; then
  alias lg='lazygit'
fi

# --- Kubernetes (same set as the exam shell so muscle memory carries over) -------
if command -v kubectl >/dev/null 2>&1; then
  alias k='kubectl'
  alias kgp='kubectl get pods'
  alias kgpa='kubectl get pods --all-namespaces'
  alias kgs='kubectl get svc'
  alias kgd='kubectl get deploy'
  alias kgn='kubectl get nodes'
  alias kgns='kubectl get ns'
  alias kga='kubectl get all'
  alias kgcm='kubectl get configmaps'
  alias kgsec='kubectl get secret'
  alias kge='kubectl get events --sort-by=.lastTimestamp'
  alias kaf='kubectl apply -f'
  alias kdf='kubectl delete -f'
  alias kdesc='kubectl describe'
  alias klogs='kubectl logs'
  alias klf='kubectl logs -f'
  alias kexec='kubectl exec -it'
  alias krs='kubectl rollout status'
  alias krh='kubectl rollout history'
  alias kctx='kubectl config current-context'
  alias kctxs='kubectl config get-contexts'
  alias kcuc='kubectl config use-context'
fi

# --- Terraform (apply/destroy prompt for confirmation, on purpose) ---------------
if command -v terraform >/dev/null 2>&1; then
  alias tf='terraform'
  alias tfi='terraform init'
  alias tfiu='terraform init -upgrade'
  alias tff='terraform fmt'
  alias tfv='terraform validate'
  alias tfp='terraform plan'
  alias tfa='terraform apply'
  alias tfd='terraform destroy'
  alias tfo='terraform output'
  alias tfc='terraform console'
  alias tfs='terraform state'
  alias tfsl='terraform state list'
  alias tfsh='terraform show'
  alias tfw='terraform workspace'
  alias tfwl='terraform workspace list'
  alias tfws='terraform workspace select'
fi

# --- Containers ------------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  alias dps='docker ps'
  alias dcu='docker compose up -d'
  alias dcd='docker compose down'
  alias dcl='docker compose logs -f'
  alias dcps='docker compose ps'
fi

# --- Homebrew (update shows what changed; upgrading stays a deliberate step) -----
if command -v brew >/dev/null 2>&1; then
  alias bi='brew install'
  alias bs='brew search'
  alias bu='brew update && brew outdated'
fi

# --- tmux ------------------------------------------------------------------------
if command -v tmux >/dev/null 2>&1; then
  alias tm='tmux new-session -A -s main'
  alias tls='tmux ls'
  alias ta='tmux attach -t'
  alias tn='tmux new -s'
fi

# --- AI coding CLIs --------------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  alias clr='claude --resume'
  alias clc='claude --continue'
fi
if command -v codex >/dev/null 2>&1; then
  alias cxr='codex resume'
fi
if command -v gemini >/dev/null 2>&1; then
  alias gmr='gemini --resume'
fi
