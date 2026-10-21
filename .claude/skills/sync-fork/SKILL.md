---
name: sync-fork
description: Syncs this fork (georgyo/nix) with both Determinate Nix (DeterminateSystems/nix-src main) and upstream Nix (NixOS/nix master) by merging them into local main, resolving conflicts, fixing the build and tests, and force-pushing to georgyo master. Use when the user asks to rebase, merge, sync or update the fork with Determinate Nix and/or upstream Nix.
argument-hint: "[--no-push]"
user-invocable: true
---

# Syncing the fork with Determinate Nix and upstream Nix

This checkout combines Determinate Nix and upstream Nix, plus a few fork-only commits (e.g. the `nix-eval-jobs` flake output). The history is merge-based. When the user says "rebase", they mean this merge sync: never rebase or rewrite `main`.

Copy this checklist and check off items as you complete them:

```
- [ ] Check the remotes and the working tree
- [ ] Step 1: Merge origin/main (Determinate Nix)
- [ ] Step 2: Merge upstream/master (upstream Nix)
- [ ] Step 3: Fix the build of things that merged cleanly but broke
- [ ] Step 4: Build and run all tests with nix-make
- [ ] Step 5: Run `nix flake check` and build nix-eval-jobs
- [ ] Step 6: Format, commit fixes, push
```

## Remotes

* `origin` is Determinate Nix, `https://github.com/DeterminateSystems/nix-src`, branch `main`. Local `main` tracks it, but **never push there**.
* `upstream` is upstream Nix, `github.com:NixOS/nix`, branch `master`.
* `georgyo` is the user's fork, `git@github.com:georgyo/nix.git`. Its `master` mirrors local `main`. This is the push target.

Check that the working tree is clean and that `main` equals `georgyo/master` (or explain the difference to the user). Then `git fetch origin && git fetch upstream && git fetch georgyo`.

## Step 1: Merge Determinate Nix

`git merge --no-ff --no-edit origin/main`. Merge Determinate first: it is usually the smaller merge, and its conflicts are mostly with upstream changes from the previous sync.

Resolve every conflict by understanding **both** sides, not by picking one:

* Read the incoming commit (`git log --oneline HEAD..origin/main -- <file>`, then `git show <rev>`) to see what it is for. Determinate commit messages are detailed and usually say why.
* Keep upstream's API (it is the newer one in this tree) and port the Determinate feature onto it. Typical cases:
  * Determinate fixes a bug in code that upstream has since refactored: re-apply the fix in the refactored code.
  * Both sides fixed the same bug differently (common for security fixes, which land in both): keep one complete fix. Prefer upstream's when it covers Determinate's, so the next upstream merge is clean.
  * Determinate removes something (an option, a field) that upstream still uses, or vice versa: check with `git grep <name> HEAD`, `git grep <name> origin/main` and `git grep <name> upstream/master` which side removed it and why. Remove it when nothing uses it anymore.
  * Both sides add entries to a list (protocol features, includes, options): keep both.
* `.version`: keep upstream's version (e.g. `2.36.0`); Determinate's own version is in `.version-determinate`.
* Deleted-vs-modified `.github/` files: keep them deleted when Determinate deleted them.

Search for leftover markers before committing: `git diff --check` and `git grep -n -E '^(<<<<<<<|>>>>>>>)'`. Build (step 3) before committing, so that fixes to the merge are part of the merge commit. Commit with the default merge message (`Merge remote-tracking branch 'origin/main'`) plus the `Assisted-by:` trailer from AGENTS.md.

## Step 2: Merge upstream Nix

`git merge --no-ff --no-edit upstream/master`, and resolve conflicts as in step 1. Upstream merges can be big (dozens of conflicted files). If there are many, split the work by file among subagents (or a workflow if the user opted into one), then have the results verified independently: every resolution must keep the features of both sides.

* CI and release infrastructure follows Determinate: for `.github/`, `flake.lock` (Determinate pins its inputs via FlakeHub) and `packaging/hydra.nix` (Determinate dropped upstream's installer jobs), take the `HEAD` side (`git checkout --ours <file>`, or drop upstream's hunks). Do check that upstream renames still line up, e.g. upstream moved `packaging/installer` to `packaging/scripted-installer`.
* When upstream has merged its own version of a fix that Determinate already has, the conflict can be in a different place than the code: e.g. Determinate moved the body of `LocalStore::addToStore()` into `doAddToStore()`, so upstream's fix in `addToStore()` conflicts with the call to `doAddToStore()`. Keep Determinate's structure, and make sure the fix is present in it (port it in step 1 if Determinate's version differs, so this step is trivial).
* Upstream may rewrite code that Determinate extended (e.g. `HookInstance` moved from `startProcess()` with a lambda to `spawnProgram()` with `SpawnOptions`). Take upstream's version and re-add Determinate's additions with the new API (there: `TRACEPARENT` via `SpawnOptions::environment`).

Upstream API changes that have needed porting in Determinate-only code before (use these as a guide to the kind of change to expect):

* `RunOptions` gained `.spawnOptions = SpawnOptions{.program, .lookupPath, .args (OsStrings), .environment (OsStringMap)}`.
* Goal coroutines return `Result{ExitCode, BuildResult}`; `doneSuccess()` / `doneFailure()` are gone.
* Logger fields are `std::span<const Logger::Field>`; `Logger::Field` is a `std::variant` subclass (no `.raw`). On the daemon wire, `Verbosity` must be written as `std::to_underlying(lvl)`.
* `parseFlakeRef*` and `FlakeRef::fromAttrs` no longer take `fetchSettings`.
* `InstallableValue::toValue(state, AutoCall)`; `getAutoArgs()` returns `const Bindings *`.
* `Derivation::inputs` is a `std::set<SingleDerivedPath>` (no `inputDrvs` / `inputSrcs`).

## Step 3: Fix what merged cleanly but broke

Files without conflicts can still break: Determinate code calling an API that upstream changed, or vice versa. Find all errors at once with a local meson build:

```
nix develop -c bash -c 'meson setup --reconfigure build && ninja -C build -k 0' 2>&1 | grep -E 'error:|FAILED'
```

Do this after each merge, before committing it.

If linking fails with a missing `/nix/store/...` library, or meson can't find a dependency, the build directory cached a dev shell that has changed (e.g. Determinate updated a patched dependency). `--clearcache` is not enough because meson also caches `PKG_CONFIG_PATH`: `rm -rf build` and set it up again with `meson setup build -Dlibexpr:wasm=enabled -Dlibstore:wasm=enabled`. The `wasm` options default to `auto`, which leaves wasm disabled; without them the resulting `nix` can't evaluate nix-make (step 4).

**nix-make doesn't read `meson.build`.** It compiles every source file under a component's directory, minus `excludeSources`, and takes config macros from `configHeaders` in the component's `src/*/make.nix`. So check `git diff <before>..HEAD -- '*meson.build'` for:

* new `configdata*.set*('X', ...)`: add `X` to `configHeaders` (using the meson default), or the build fails with "'X' was not declared";
* sources that meson only builds conditionally (benchmarks, fuzz harnesses, platform subdirectories like `darwin/` or `windows/`) that were added or moved: add or update them in `excludeSources`, or nix-make compiles them anyway (e.g. "benchmark/benchmark.h: No such file or directory" after upstream moved `derivation-parser-bench.cc` to `derivation/parser-bench.cc`, or "multiple definition of `LLVMFuzzerTestOneInput'" from the `fuzz/` harnesses).

Likewise, `tests/functional/run-tests.py` mirrors per-suite `BASH_ENV` settings by hand in `SUITE_BASH_ENV`.

## Step 4: Build and run all tests

Use the commands from AGENTS.md, with `--extra-experimental-features wasm-builtin`. nix-make's wasm needs a recent Determinate Nix (≥3.23, for `env::get_attrset`); the system `nix` may be too old ("unknown import" or "attribute 'wasm' missing"). Drive nix-make with the freshly built `build/src/nix/nix` (or a `./result/bin/nix` from an earlier build):

```
build/src/nix/nix build -L --extra-experimental-features wasm-builtin ./packaging/nix-make#release.nix-all-tests
```

Pass `--keep-going` to see all failures at once. Expected output of upstream's `lang` tests can include trace lines from upstream evaluator features that Determinate's evaluator doesn't have (e.g. "… entering the infinite recursion", which relies on upstream's `handleEvalExceptionForThunk()`). If a new test fails only on such a line, and the test still checks what it was written for, drop the line from its `.err.exp`, as was done for the existing tests. If an earlier attempt failed to evaluate, pass `--no-eval-cache` ("cached failed attribute ... unexpectedly succeeded"). To iterate on single failing tests, use the `test-runner` from AGENTS.md. Known environment-only failure: the `ps` functional test fails when builds are offloaded to eu.nixbuild.net (no `/proc/<pid>/task/<pid>/children`); it passes locally.

## Step 5: `nix flake check` and nix-eval-jobs

Run `nix flake check -L` (with the freshly built nix). It runs Determinate's flake checks, e.g. the functional tests with lazy trees enabled. A test that inspects `nix flake metadata --json | jq .path` fails with lazy trees (`path` is null); guard it with `if [[ $(nix config show lazy-trees) = false ]]`, as other tests do.

Build `nix build -L .#nix-eval-jobs`. It is the Determinate nix-eval-jobs fork pinned in `packaging/nix-eval-jobs.nix`, patched by `packaging/patches/nix-eval-jobs-nix-master-api.patch` to build against the upstream-master API in this tree. If it breaks:

* Clone the pinned rev into the scratchpad, apply the patch, fix the code, and regenerate the patch with `git diff`.
* If the fork has a newer release, consider bumping the pin (update `rev`, `version` and `hash`); drop parts of the patch that are no longer needed, or the whole patch once the fork builds unpatched.
* Run its functional tests (33 as of 3.23.1) from a checkout of the pinned rev, in its `tests-functional/` directory, with the built nix first on `PATH`:

  ```
  nix shell --impure --expr 'with import (builtins.getFlake "nixpkgs") {}; python3.withPackages (p: [ p.pytest ])' \
    -c bash -c 'PATH=<repo>/build/src/nix:$PATH NIX_EVAL_JOBS_BIN=<nix-eval-jobs out>/bin/nix-eval-jobs python3 -m pytest -q'
  ```

## Step 6: Format, commit and push

Run `nix develop -c ./maintainers/format.sh` once over the whole tree after the merges, even if you only touched C++: hooks that upstream adds (e.g. `typos`) run over Determinate-only files for the first time. Fix real problems in code. Configure exclusions for false positives (e.g. `.typos.toml`) and for files that are not worth changing, like Determinate's historical release notes. During conflict resolution, `./maintainers/format.sh clang-format` is enough. Commit fixes as separate commits on top of the merges, with messages that say what broke and why, plus the `Assisted-by:` trailer.

Unless `--no-push` was given or the user said otherwise, push with `git push --force georgyo main:master`. The push is a fast-forward in practice, but the user asked for force pushes. Never push to `origin` or `upstream`.

Finally, report to the user: the new commits that came in from each side, conflicts that needed real decisions (not just picking a side), fixes to code that merged cleanly, and the test results.
