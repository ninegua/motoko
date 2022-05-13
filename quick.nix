{ officialRelease ? false, pkgs ? import <nixpkgs> {
  overlays = [
    (import (builtins.fetchTarball
      "https://github.com/oxalica/rust-overlay/archive/master.tar.gz"))
    (self: super: {
      rustc-nightly = self.rust-bin.nightly.latest.default.override {
        targets = [
          "wasm32-unknown-emscripten"
          "wasm32-wasi"
          "i686-unknown-linux-gnu"
        ];
        extensions = [ "rust-src" ];
      };
      v8 = self.v8_8_x;
    })
  ];
} }:
let
  releaseVersion =
    import ./nix/releaseVersion.nix { inherit pkgs officialRelease; };
  subpath = import ./nix/gitSource.nix;
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_12;
  obelisk = import ./nix/ocaml-obelisk.nix {
    inherit (pkgs) lib fetchFromGitHub;
    inherit (ocamlPackages) ocaml dune_2;
    inherit ocamlPackages;
    inherit (pkgs.stdenv) mkDerivation;
  };
  musl-wasi-src = pkgs.fetchFromGitHub {
    owner = "WebAssembly";
    repo = "wasi-libc";
    rev = "5ccfab77b097a5d0184f91184952158aa5904c8d";
    sha256 = "1kxcy616vnqw4q2xkng9q67mgmq3gw2h4z6hkcwrqw1fjjp5qnbz";
  };

  libtommath_src = pkgs.fetchFromGitHub {
    owner = "libtom";
    repo = "libtommath";
    sha256 = "0cj4xdbh874hi8hx9ajygqk5411cnv260mfjrn68fsi9a6dw56ff";
    rev = "6ca6898bf37f583c4cc9943441cd60dd69f4b8f2";
  };
  rtsBuildInputs = with pkgs;
    [
      # pulls in clang (wrapped) and clang-13 (unwrapped)
      llvmPackages_13.clang
      # pulls in wasm-ld
      llvmPackages_13.lld
      llvmPackages_13.bintools
      rustc-nightly
      wasmtime
      rust-bindgen
      python3
    ] ++ pkgs.lib.optional pkgs.stdenv.isDarwin [ libiconv ];

  llvmEnv = ''
    # When compiling to wasm, we want to have more control over the flags,
    # so we do not use the nix-provided wrapper in clang
    export WASM_CLANG="clang-13"
    export WASM_LD=wasm-ld
    # because we use the unwrapped clang, we have to pass in some flags/paths
    # that otherwise the wrapped clang would take care for us
    export WASM_CLANG_LIB="${pkgs.llvmPackages_13.clang-unwrapped.lib}"

    # When compiling natively, we want to use `clang` (which is a nixpkgs
    # provided wrapper that sets various include paths etc).
    # But for some reason it does not handle building for Wasm well, so
    # there we use plain clang-13. There is no stdlib there anyways.
    export CLANG="${pkgs.clang_13}/bin/clang"
  '';
  commonBuildInputs = pkgs: [
    ocamlPackages.dune_2
    ocamlPackages.ocaml
    ocamlPackages.atdgen
    ocamlPackages.checkseum
    ocamlPackages.findlib
    ocamlPackages.menhir
    ocamlPackages.menhirLib
    ocamlPackages.cow
    ocamlPackages.num
    ocamlPackages.stdint
    ocamlPackages.wasm
    ocamlPackages.vlq
    ocamlPackages.zarith
    ocamlPackages.yojson
    ocamlPackages.ppxlib
    ocamlPackages.ppx_blob
    ocamlPackages.ppx_inline_test
    ocamlPackages.ocaml-migrate-parsetree
    ocamlPackages.ppx_tools_versioned
    ocamlPackages.bisect_ppx
    obelisk
    ocamlPackages.uucp
    pkgs.perl
    pkgs.removeReferencesTo
  ];

  ocaml_exe = name: bin: rts:
    let profile = "release";
    in pkgs.stdenv.mkDerivation {
      inherit name;

      allowedRequisites = [ ];

      src = subpath ./src;

      buildInputs = commonBuildInputs pkgs;

      MOTOKO_RELEASE = releaseVersion;

      extraDuneOpts = "";

      # we only need to include the wasm statically when building moc, not
      # other binaries
      buildPhase = ''
        patchShebangs .
      '' + pkgs.lib.optionalString (rts != null) ''
        ./rts/gen.sh ${rts}/rts
      '' + ''
        make DUNE_OPTS="--display=short --profile ${profile} $extraDuneOpts" ${bin}
      '';

      installPhase = ''
        mkdir -p $out/bin
        cp --verbose --dereference ${bin} $out/bin
      '' + pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
        # there are references to darwin system libraries
        # in the binaries. But curiously, we can remove them
        # an the binaries still work. They are essentially static otherwise.
        remove-references-to \
          -t ${pkgs.darwin.Libsystem} \
          -t ${pkgs.darwin.CF} \
          -t ${pkgs.libiconv} \
          $out/bin/*
      '' + ''
        # also, there is a refernece to /nix/store/…/share/menhir/standard.mly.
        # Let's remove that, too
        remove-references-to \
          -t ${ocamlPackages.menhir} \
          $out/bin/*
        # sanity check
        $out/bin/* --help >/dev/null
      '';
    };

  musl-wasi-sysroot = pkgs.stdenv.mkDerivation {
    name = "musl-wasi-sysroot";
    src = musl-wasi-src;
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      make SYSROOT="$out" include_dirs
    '';
  };

in rec {
  rts = let
    # Build Rust package cargo-vendor-tools
    cargoVendorTools = pkgs.rustPlatform.buildRustPackage rec {
      name = "cargo-vendor-tools";
      src = subpath "./rts/${name}/";
      cargoSha256 = "sha256-CrtZQTac95MEbk3uapviLgcQjEt5VUnTOG9fiJXIAU8=";
    };

    # Path to vendor-rust-std-deps, provided by cargo-vendor-tools
    vendorRustStdDeps = "${cargoVendorTools}/bin/vendor-rust-std-deps";

    # SHA256 of Rust std deps
    rustStdDepsHash = "sha256-MIYFGp4QhoEK8wVtED1yolKnufBhv+ylEfMK/MAJ6q8=";

    # Vendor directory for Rust std deps
    rustStdDeps = pkgs.stdenvNoCC.mkDerivation {
      name = "rustc-std-deps";

      nativeBuildInputs = with pkgs; [ curl ];

      buildCommand = ''
        mkdir $out
        cd $out
        echo ${vendorRustStdDeps} ${pkgs.rustc-nightly} .
        ${vendorRustStdDeps} ${pkgs.rustc-nightly} .
      '';

      outputHash = rustStdDepsHash;
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
    };

    # Vendor tarball of the RTS
    rtsDeps = pkgs.rustPlatform.fetchCargoTarball {
      name = "motoko-rts-deps";
      src = subpath ./rts;
      sourceRoot = "rts/motoko-rts-tests";
      sha256 = "sha256-VKNXQ7uT5njmZ4RlF1Lebyy7hPSw+KRjG8ntCXfw/Y4";
      copyLockfile = true;
    };

    # Unpacked RTS deps
    rtsDepsUnpacked = pkgs.stdenvNoCC.mkDerivation {
      name = rtsDeps.name + "-unpacked";
      buildCommand = ''
        tar xf ${rtsDeps}
        mv *.tar.gz $out
      '';
    };

    # All dependencies needed to build the RTS, including Rust std deps, to
    # allow `cargo -Zbuild-std`. (rust-lang/wg-cargo-std-aware#23)
    allDeps = pkgs.symlinkJoin {
      name = "merged-rust-deps";
      paths = [ rtsDepsUnpacked rustStdDeps ];
    };

  in pkgs.stdenv.mkDerivation {
    name = "moc-rts";

    src = subpath ./rts;

    nativeBuildInputs =
      [ pkgs.makeWrapper pkgs.removeReferencesTo pkgs.cacert ];

    buildInputs = rtsBuildInputs;

    preBuild = ''
      export CARGO_HOME=$PWD/cargo-home

      # This replicates logic from nixpkgs’ pkgs/build-support/rust/default.nix
      mkdir -p $CARGO_HOME
      echo "Using vendored sources from ${rtsDeps}"
      unpackFile ${allDeps}
      cat > $CARGO_HOME/config <<__END__
        [source."crates-io"]
        "replace-with" = "vendored-sources"

        [source."vendored-sources"]
        "directory" = "$(stripHash ${allDeps})"
      __END__

      ${llvmEnv}
      export TOMMATHSRC=${libtommath_src}
      export MUSLSRC=${musl-wasi-src}/libc-top-half/musl
      export MUSL_WASI_SYSROOT=${musl-wasi-sysroot}
    '';

    doCheck = true;

    checkPhase = ''
      make test
    '';

    installPhase = ''
      mkdir -p $out/rts
      cp mo-rts.wasm $out/rts
      cp mo-rts-debug.wasm $out/rts
    '';

    # This needs to be self-contained. Remove mention of nix path in debug
    # message.
    preFixup = ''
      remove-references-to \
        -t ${pkgs.rustc-nightly} \
        -t ${rtsDeps} \
        -t ${rustStdDeps} \
        $out/rts/mo-rts.wasm $out/rts/mo-rts-debug.wasm
    '';

    allowedRequisites = [ ];
  };

  moc = ocaml_exe "moc" "moc" rts;
  mo-ld = ocaml_exe "mo-ld" "mo-ld" null;
  mo-ide = ocaml_exe "mo-ide" "mo-ide" null;
  mo-doc = ocaml_exe "mo-doc" "mo-doc" null;
  didc = ocaml_exe "didc" "didc" null;
  deser = ocaml_exe "deser" "deser" null;
  candid-tests = ocaml_exe "candid-tests" "candid-tests" null;
}
