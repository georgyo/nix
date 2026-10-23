---
synopsis: "New setting `prefer-local-builds`"
---

Nix normally sends builds to [remote build machines](@docroot@/command-ref/conf-file.md#conf-builders) first and only builds locally when none of them can take the build.
The new [`prefer-local-builds`](@docroot@/command-ref/conf-file.md#conf-prefer-local-builds) setting reverses this: when enabled, Nix builds locally whenever a local build slot (see [`max-jobs`](@docroot@/command-ref/conf-file.md#conf-max-jobs)) is free, and only uses the remote build machines once all local slots are busy.
