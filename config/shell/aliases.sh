# shellcheck shell=sh
# platform-workbench canonical aliases. Sourced by bash and zsh (see bashrc / zshrc).
#
# Rules: plain `alias` lines only; optional tools are guarded with `command -v`;
# never shadow a standard command with different behaviour; never auto-approve
# anything destructive; no paths, hosts or secrets. Functions live in functions.sh.
# Names shared with oh-my-zsh plugins keep the oh-my-zsh meaning, so bash and zsh agree.
# kodekloud/ (cka-shell.sh and the per-topic */*-shell.sh) are the only other places
# aliases are defined (paste-ins for disposable nodes); keep names in step with this file.
# scripts/aliases-snippet.sh turns this file into a paste-in installer (task aliases).

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
  alias gsta='git stash push'
  alias grb='git rebase'
  alias gpf='git push --force-with-lease'
fi
if command -v lazygit >/dev/null 2>&1; then
  alias lg='lazygit'
fi
if command -v gh >/dev/null 2>&1; then
  alias ghpr='gh pr create --fill'
  alias ghprl='gh pr list'
  alias ghprv='gh pr view --web'
  alias ghrw='gh run watch'
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
  alias kgpw='kubectl get pods --watch'
  alias kgpwide='kubectl get pods -o wide'
  alias kgnw='kubectl get nodes -o wide'
  alias kgi='kubectl get ingress'
  alias kgpvc='kubectl get pvc'
  alias ktop='kubectl top pods'
  alias ktopn='kubectl top nodes'
  alias kpf='kubectl port-forward'
  alias kdry='kubectl --dry-run=client -o yaml'
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
  alias tfwn='terraform workspace new'
  alias tffr='terraform fmt -recursive'
  alias tfpo='terraform plan -out=tfplan'
  alias tfpr='terraform providers'
  alias tfg='terraform graph'
  alias tfvr='terraform version'
fi
if command -v tflint >/dev/null 2>&1; then
  alias tfl='tflint'
fi
if command -v terragrunt >/dev/null 2>&1; then
  alias tg='terragrunt'
fi

# --- Helm ------------------------------------------------------------------------
if command -v helm >/dev/null 2>&1; then
  alias hm='helm'
  alias hmls='helm list --all-namespaces'
  alias hmi='helm upgrade --install'
  alias hmt='helm template'
  alias hms='helm status'
  alias hmv='helm get values'
  alias hmh='helm history'
  alias hmrs='helm repo update'
  alias hmsr='helm search repo'
  alias hmlint='helm lint'
fi

# --- AWS CLI (read-only helpers; no alias creates or deletes anything) ------------
if command -v aws >/dev/null 2>&1; then
  alias awsid='aws sts get-caller-identity'
  alias awscfg='aws configure list'
  alias awsprof='aws configure list-profiles'
  alias awssso='aws sso login'
  alias awss3='aws s3 ls'
  alias awsec2='aws ec2 describe-instances --query "Reservations[].Instances[].[InstanceId,State.Name,InstanceType]" --output table'
  alias awseks='aws eks list-clusters'
  alias awseksc='aws eks update-kubeconfig --name'
fi

# --- Azure CLI -------------------------------------------------------------------
if command -v az >/dev/null 2>&1; then
  alias azlogin='az login'
  alias azacc='az account show --output table'
  alias azaccs='az account list --output table'
  alias azsub='az account set --subscription'
  alias azrg='az group list --output table'
  alias azvm='az vm list --show-details --output table'
  alias azaks='az aks list --output table'
  alias azaksc='az aks get-credentials --name'
fi

# --- Google Cloud ----------------------------------------------------------------
if command -v gcloud >/dev/null 2>&1; then
  alias gcpauth='gcloud auth list'
  alias gcpproj='gcloud config get-value project'
  alias gcpprojs='gcloud projects list'
  alias gcpset='gcloud config set project'
  alias gcpvm='gcloud compute instances list'
  alias gcpgke='gcloud container clusters list'
  alias gcpgkec='gcloud container clusters get-credentials'
fi

# --- Ansible ---------------------------------------------------------------------
if command -v ansible-playbook >/dev/null 2>&1; then
  alias ap='ansible-playbook'
  alias apc='ansible-playbook --check --diff'
  alias apl='ansible-playbook --list-tasks'
  alias apsc='ansible-playbook --syntax-check'
fi
if command -v ansible >/dev/null 2>&1; then
  alias aping='ansible all -m ping'
fi
if command -v ansible-inventory >/dev/null 2>&1; then
  alias ainv='ansible-inventory --graph'
fi
if command -v ansible-lint >/dev/null 2>&1; then
  alias alint='ansible-lint'
fi
if command -v ansible-vault >/dev/null 2>&1; then
  alias avv='ansible-vault view'
  alias ave='ansible-vault edit'
fi
if command -v ansible-galaxy >/dev/null 2>&1; then
  alias agi='ansible-galaxy install -r requirements.yml'
fi

# --- Containers ------------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  alias dps='docker ps'
  alias dpsa='docker ps -a'
  alias dimg='docker images'
  alias dex='docker exec -it'
  alias dlf='docker logs -f'
  alias dins='docker inspect'
  alias dst='docker stats --no-stream'
  alias dcu='docker compose up -d'
  alias dcd='docker compose down'
  alias dcl='docker compose logs -f'
  alias dcps='docker compose ps'
fi
# Podman is the default engine on RHEL-family hosts: same shapes, `p` prefix.
if command -v podman >/dev/null 2>&1; then
  alias pps='podman ps'
  alias ppsa='podman ps -a'
  alias pimg='podman images'
  alias pex='podman exec -it'
  alias plf='podman logs -f'
  alias pins='podman inspect'
  alias pst='podman stats --no-stream'
fi

# --- Linux ops (systemd, logs, networking) ---------------------------------------
if command -v systemctl >/dev/null 2>&1; then
  alias scs='systemctl status'
  alias scf='systemctl --failed'
  alias scl='systemctl list-units --type=service --state=running'
  alias sce='systemctl is-enabled'
  alias scu='systemctl --user'
fi
if command -v journalctl >/dev/null 2>&1; then
  alias jc='journalctl'
  alias jcf='journalctl -f'
  alias jcu='journalctl -u'
  alias jce='journalctl -p err -b'
fi
if command -v ip >/dev/null 2>&1; then
  alias ipa='ip -br address'
  alias ipr='ip route'
fi
if command -v free >/dev/null 2>&1; then
  alias mem='free -h'
fi
if command -v lsblk >/dev/null 2>&1; then
  alias lsb='lsblk'
fi
alias psg='ps aux | grep -v grep | grep -i'

# --- Tailscale -------------------------------------------------------------------
if command -v tailscale >/dev/null 2>&1; then
  alias ts='tailscale'
  alias tss='tailscale status'
  alias tsip='tailscale ip'
  alias tsping='tailscale ping'
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
