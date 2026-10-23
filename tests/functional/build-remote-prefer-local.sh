#!/usr/bin/env bash

source common.sh

requireSandboxSupport
requiresUnprivilegedUserNamespaces
[[ "${busybox-}" =~ busybox ]] || skipTest "no busybox"

# Avoid store dir being inside sandbox build-dir
unset NIX_STORE_DIR

chmod -R +w "$TEST_ROOT/machine"* || true
rm -rf "$TEST_ROOT/machine"* || true

builders="$TEST_ROOT/machine1 - - 4 1"

# Build the leaves of build-remote-prefer-local.nix (unique per seed) and print
# how many of them were built on the remote machine.
buildAndCountRemote() {
    local seed="$1"
    local count="$2"
    shift 2
    nix build -L -f build-remote-prefer-local.nix --no-link \
        --arg busybox "$busybox" \
        --argstr seed "$seed" \
        --arg count "$count" \
        --store "$TEST_ROOT/machine0" \
        --builders "$builders" \
        "$@" >&2
    local remoteLeaves
    remoteLeaves=$(nix path-info --store "$TEST_ROOT/machine1" --all | grep -cE -- '-prefer-local-[0-9]+$' || true)
    echo $(( remoteLeaves - remoteSoFar ))
}

remoteSoFar=0

# By default, a build goes to the remote machine even if there is a free local slot.
remote=$(buildAndCountRemote default 1 --max-jobs 1)
[[ $remote -eq 1 ]]
remoteSoFar=$(( remoteSoFar + remote ))

# With prefer-local-builds, it is built locally instead.
remote=$(buildAndCountRemote local 1 --max-jobs 1 --prefer-local-builds)
[[ $remote -eq 0 ]]

# Once all local slots are busy, the remaining builds overflow to the remote
# machine. The first leaf always gets the free local slot.
remote=$(buildAndCountRemote overflow 4 --max-jobs 1 --prefer-local-builds)
[[ $remote -ge 1 && $remote -le 3 ]]
