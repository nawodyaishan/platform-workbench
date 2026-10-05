#!/usr/bin/env bash
# platform-workbench lifecycle engine.
#
#   workbench.sh <bootstrap|update|verify> --profile <macos|rhel|ubuntu|proxmox>
#                [--dry-run] [--extras go,node,cka] [--only MOD,...]
#                [--expect-host H] [--yes] [--force-profile]
#
# bootstrap  install and wire everything the profile lists (idempotent; also the repair path)
# update     upgrade only profile-managed packages, then re-apply wiring
# verify     read-only; exit 1 if any check fails
# --only     run just these modules of the profile, in profile order
# shellcheck disable=SC2034  # profile variables are consumed by the sourced modules
set -euo pipefail

WB_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export WB_ROOT

usage() { sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }

VERB=""; WB_PROFILE=""; DRY_RUN=0; WB_EXTRAS=""; WB_ONLY=""; WB_EXPECT_HOST=""; WB_YES=0; WB_FORCE_PROFILE=0
[ $# -ge 1 ] || usage
case "$1" in bootstrap|update|verify) VERB=$1; shift ;; -h|--help) usage 0 ;; *) usage ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --profile)       [ $# -ge 2 ] || usage; WB_PROFILE=$2; shift 2 ;;
    --dry-run)       DRY_RUN=1; shift ;;
    --extras)        [ $# -ge 2 ] || usage; WB_EXTRAS=$2; shift 2 ;;
    --only)          [ $# -ge 2 ] || usage; WB_ONLY=$2; shift 2 ;;
    --expect-host)   [ $# -ge 2 ] || usage; WB_EXPECT_HOST=$2; shift 2 ;;
    --yes)           WB_YES=1; shift ;;
    --force-profile) WB_FORCE_PROFILE=1; shift ;;
    -h|--help)       usage 0 ;;
    *)               echo "unknown option: $1" >&2; usage ;;
  esac
done
export DRY_RUN WB_EXPECT_HOST WB_YES WB_FORCE_PROFILE WB_PROFILE
[ -n "$WB_PROFILE" ] || { echo "--profile is required" >&2; usage; }
[ -r "$WB_ROOT/bootstrap/profiles/$WB_PROFILE.sh" ] || { echo "unknown profile: $WB_PROFILE" >&2; usage; }

# shellcheck source=lib/common.sh
. "$WB_ROOT/bootstrap/lib/common.sh"
# shellcheck source=lib/detect.sh
. "$WB_ROOT/bootstrap/lib/detect.sh"
# shellcheck source=lib/packages.sh
. "$WB_ROOT/bootstrap/lib/packages.sh"
# shellcheck source=lib/hosts.sh
. "$WB_ROOT/bootstrap/lib/hosts.sh"
# shellcheck source=lib/install.sh
. "$WB_ROOT/bootstrap/lib/install.sh"

# shellcheck disable=SC2329
extra_on() { case ",$WB_EXTRAS," in *",$1,"*) return 0 ;; esac; return 1; }

# Profile defaults, then the profile itself.
MODULES=(); PKGS_BASE=(); PKGS_NET=(); PKGS_ADMIN=(); MAC_APPS=()
CONTAINER_ENGINE=none; K8S_MINOR=""; GO_VERSION=""
# shellcheck source=/dev/null
. "$WB_ROOT/bootstrap/profiles/$WB_PROFILE.sh"
if extra_on k8s-cluster; then
  die "k8s-cluster provisioning belongs to the homelab project; use this profile for client/node tools only"
fi

# --only: keep the listed modules, in profile order. A name the profile lacks is an error,
# so a typo never turns into a run that silently does nothing.
if [ -n "$WB_ONLY" ]; then
  for m in $(printf '%s' "$WB_ONLY" | tr ',' ' '); do
    case " ${MODULES[*]-} " in *" $m "*) ;; *) echo "--only: profile $WB_PROFILE has no module '$m'" >&2; usage ;; esac
  done
  kept=()
  for m in ${MODULES[@]+"${MODULES[@]}"}; do
    case ",$WB_ONLY," in *",$m,"*) kept+=("$m") ;; esac
  done
  MODULES=(${kept[@]+"${kept[@]}"})
fi

detect_os
check_profile_host "$WB_PROFILE" "$WB_FORCE_PROFILE"
check_root_policy "$WB_PROFILE"
init_sudo

# Proxmox is a hypervisor host: any change needs a typed confirmation.
if [ "$WB_PROFILE" = proxmox ] && [ "$VERB" != verify ] && ! is_dry_run; then
  confirm "This modifies the Proxmox host $(hostname)." "proxmox"
fi

printf 'platform-workbench %s  profile=%s  host=%s (%s)%s\n' "$VERB" "$WB_PROFILE" "$(hostname)" "$OS_PRETTY_NAME" "$(is_dry_run && echo '  [dry-run]')"

for m in ${MODULES[@]+"${MODULES[@]}"}; do
  # shellcheck source=/dev/null
  . "$WB_ROOT/bootstrap/modules/$m.sh"
  "${m}_${VERB}"
done

hdr "summary"
printf '  ok=%d warn=%d fail=%d n/a=%d changed=%d\n' "$N_OK" "$N_WARN" "$N_FAIL" "$N_NA" "$N_CHANGED"
if [ "$N_FAIL" -gt 0 ]; then exit 1; fi
if [ "$VERB" != verify ] && ! is_dry_run; then info "verify with: bootstrap/workbench.sh verify --profile $WB_PROFILE${WB_EXTRAS:+ --extras $WB_EXTRAS}${WB_ONLY:+ --only $WB_ONLY}"; fi
exit 0
