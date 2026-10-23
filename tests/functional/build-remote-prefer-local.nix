{
  busybox,
  seed,
  count ? 1,
}:

with import ./config.nix;

let
  mkLeaf =
    n:
    derivation {
      inherit system;
      name = "prefer-local-${toString n}";
      builder = busybox;
      args = [
        "sh"
        "-ec"
        "i=0; while [ $i -lt 200000 ]; do i=$((i + 1)); done; echo ${seed} ${toString n} > $out"
      ];
    };
in
derivation {
  inherit system;
  name = "prefer-local-top";
  builder = busybox;
  inputs = builtins.genList mkLeaf count;
  args = [
    "sh"
    "-c"
    "echo $inputs > $out"
  ];
  preferLocalBuild = true;
}
