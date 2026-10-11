# libnixfetchers, transcribed from meson.build.
{
  nixMake,
  nix-util,
  nix-store,
}:

nixMake.mkComponent {
  name = "determinate-nix-fetchers";
  libName = "nixfetchers";

  deps = [
    nix-util
    nix-store
  ];

  root = ./.;

  includeDirs = [
    ""
    "include"
  ];

  files = nixMake.commonSupportFiles // {
    "builtin-flake-registry.json.gen.hh" = nixMake.mkStringHeader ./builtin-flake-registry.json;
  };

  configHeaders = {
    "fetchers-config-private.hh" = {
      GIT_PROGRAM = "git";
      HG_PROGRAM = "hg";
    };
  };

  linkFlags = [ "-Wl,--wrap=__assert_fail" ];
}
