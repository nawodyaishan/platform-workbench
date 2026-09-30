#!/usr/bin/env bash
# Paste into a disposable KodeKloud Bash shell. Session scoped; no installs.
if command -v kubectl >/dev/null 2>&1; then
  alias k='kubectl'
  if ! type __start_kubectl >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    source <(kubectl completion bash)
  fi
  type __start_kubectl >/dev/null 2>&1 && complete -F __start_kubectl k
fi
export EDITOR=vim KUBE_EDITOR=vim
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'
export VIMINIT='set expandtab tabstop=2 shiftwidth=2 softtabstop=2 autoindent number | syntax on'
hostname
if command -v kubectl >/dev/null 2>&1; then kubectl config current-context; fi
