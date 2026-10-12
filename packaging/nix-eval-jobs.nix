# nix-eval-jobs built against this Nix, adapted from its default.nix.
{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  cmake,
  ninja,
  pkg-config,
  boost,
  curl,
  gtest,
  mimalloc,
  nlohmann_json,
  nixComponents,
}:

stdenv.mkDerivation {
  pname = "nix-eval-jobs";
  version = "3.23.1";

  # Determinate Systems' fork, which tracks Determinate Nix.
  src = fetchFromGitHub {
    owner = "DeterminateSystems";
    repo = "nix-eval-jobs";
    rev = "6f0af6ca30d730eb7bb19a5dcd9e998a3b96dcea";
    hash = "sha256-wEoYrgABnjqOoUvFQz3NK4wwPHuqxOCipGRCs50S7is=";
  };

  patches = [
    # Port to the API changes from upstream Nix master that this tree
    # has merged but Determinate Nix hasn't released yet. Drop once the
    # fork catches up.
    ./patches/nix-eval-jobs-nix-master-api.patch
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    # nlohmann_json can only be discovered via its CMake files.
    cmake
  ];

  buildInputs = [
    boost
    curl
    mimalloc
    nlohmann_json
    nixComponents.nix-store
    nixComponents.nix-fetchers
    nixComponents.nix-expr
    nixComponents.nix-flake
    nixComponents.nix-main
    nixComponents.nix-cmd
  ];

  checkInputs = [
    gtest
    nixComponents.nix-util-test-support
  ];

  doCheck = true;

  # The Nix headers require C++23.
  mesonFlags = [ (lib.mesonOption "cpp_std" "c++23") ];

  outputs = [
    "out"
    "dev"
  ];

  passthru = {
    inherit nixComponents;
    # For nix-fast-build.
    nix = nixComponents.nix-cli;
  };

  meta = {
    description = "Hydra's builtin hydra-eval-jobs as a standalone, built against this Nix";
    homepage = "https://github.com/DeterminateSystems/nix-eval-jobs";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.unix;
    mainProgram = "nix-eval-jobs";
  };
}
