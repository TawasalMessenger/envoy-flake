{ pkgs, go_1_15, src, version }:

with pkgs;
let
  toolchainPatch = { cmake, ninja, gnumake }: ''
    # pass in the paths to rules_foreign_cc as custom toolchains to work around
    # https://github.com/bazelbuild/rules_foreign_cc/issues/225
    cat >> BUILD <<EOF
    load("@rules_foreign_cc//tools/build_defs/native_tools:native_tools_toolchain.bzl", "native_tool_toolchain")
    native_tool_toolchain(
        name = "nix_cmake",
        path = "${cmake}/bin/cmake",
        visibility = ["//visibility:public"],
    )
    toolchain(
        name = "nix_cmake_toolchain",
        toolchain = ":nix_cmake",
        toolchain_type = "@rules_foreign_cc//tools/build_defs:cmake_toolchain",
    )
    native_tool_toolchain(
        name = "nix_ninja",
        path = "${ninja}/bin/ninja",
        visibility = ["//visibility:public"],
    )
    toolchain(
        name = "nix_ninja_toolchain",
        toolchain = ":nix_ninja",
        toolchain_type = "@rules_foreign_cc//tools/build_defs:ninja_toolchain",
    )
    native_tool_toolchain(
        name = "nix_make",
        path = "${gnumake}/bin/make",
        visibility = ["//visibility:public"],
    )
    toolchain(
        name = "nix_make_toolchain",
        toolchain = ":nix_make",
        toolchain_type = "@rules_foreign_cc//tools/build_defs:make_toolchain",
    )
    EOF
  '';
  preBuild = ''
    rm -f .bazelversion

    sed -e 's;rules_foreign_cc_dependencies();rules_foreign_cc_dependencies(["//:nix_cmake_toolchain", "//:nix_ninja_toolchain", "//:nix_make_toolchain"], False);g' -i bazel/dependency_imports.bzl
    sed -e 's;GO_VERSION = "1.15.5";GO_VERSION = "host";g' -i bazel/dependency_imports.bzl

    sed -e 's;gn=buildtools/linux64/gn;gn=$$(command -v gn);g' -i bazel/external/wee8.genrule_cmd
    sed -e 's;ninja=third_party/depot_tools/ninja-linux64;ninja=$$(command -v ninja);g' -i bazel/external/wee8.genrule_cmd
  '';
in
buildBazelPackage.override { stdenv = gcc9Stdenv; } {
  inherit src version;
  pname = "envoy";

  nativeBuildInputs = [ autoconf automake ];

  buildInputs = [
    bash
    coreutils
    cmake
    git
    gnumake
    gn
    go_1_15
    libtool
    ninja
    python3

    bazel-buildtools
    nix
  ];

  bazel = bazel_3;
  bazelTarget = "//source/exe:envoy-static.stripped";
  bazelFetchFlags = [
    "--loading_phase_threads=HOST_CPUS"
  ];
  bazelFlags = [
    "-c opt"
    "--define=ABSOLUTE_JAVABASE=${jdk11.home}"
    "--host_javabase=@bazel_tools//tools/jdk:absolute_javabase"
    "--javabase=@bazel_tools//tools/jdk:absolute_javabase"
    "--spawn_strategy=standalone"
    "--cxxopt=-Wno-maybe-uninitialized"
    "--cxxopt=-Wno-uninitialized"

    "--//source/extensions/clusters/redis:enabled=false"
    "--//source/extensions/filters/common/lua:enabled=false"
    "--//source/extensions/filters/network/dubbo_proxy:enabled=false"
    "--//source/extensions/filters/network/kafka:enabled=false"
    "--//source/extensions/filters/network/mongo_proxy:enabled=false"
    "--//source/extensions/filters/network/mysql_proxy:enabled=false"
    "--//source/extensions/filters/network/postgres_proxy:enabled=false"
    "--//source/extensions/filters/network/redis_proxy:enabled=false"
    "--//source/extensions/filters/network/rocketmq_proxy:enabled=false"
    "--//source/extensions/filters/network/thrift_proxy:enabled=false"
    "--//source/extensions/filters/network/zookeeper_proxy:enabled=false"
    "--//source/extensions/wasm_runtime/v8:enabled=false"
  ];
  fetchConfigured = true;
  removeRulesCC = false;
  removeLocalConfigCc = true;
  removeLocal = false;

  dontAddBazelOpts = true;
  dontUseCmakeConfigure = true;
  dontUseGnConfigure = true;

  fetchAttrs = {
    preBuild = toolchainPatch { cmake = ""; ninja = ""; gnumake = ""; } + preBuild;

    preInstall = ''
      # Remove the go_sdk (it's just a copy of the go derivation) and all
      # references to it from the marker files. Bazel does not need to download
      # this sdk because we have patched the WORKSPACE file to point to the one
      # currently present in PATH. Without removing the go_sdk from the marker
      # file, the hash of it will change anytime the Go derivation changes and
      # that would lead to impurities in the marker files which would result in
      # a different sha256 for the fetch phase.
      rm -rf $bazelOut/external/{go_sdk,\@go_sdk.marker}
      sed -e '/^FILE:@go_sdk.*/d' -i $bazelOut/external/\@*.marker

      # Remove the gazelle tools, they contain go binaries that are built
      # non-deterministically. As long as the gazelle version matches the tools
      # should be equivalent.
      rm -rf $bazelOut/external/{bazel_gazelle_go_repository_tools,\@bazel_gazelle_go_repository_tools.marker}
      sed -e '/^FILE:@bazel_gazelle_go_repository_tools.*/d' -i $bazelOut/external/\@*.marker

      # Retains go build input markers
      chmod -R 755 $bazelOut/external/{bazel_gazelle_go_repository_cache,@\bazel_gazelle_go_repository_cache.marker}
      rm -rf $bazelOut/external/{bazel_gazelle_go_repository_cache,@\bazel_gazelle_go_repository_cache.marker}

      # Remove the autoconf caches
      rm -rf $bazelOut/external/com_github_gperftools_gperftools/autom4te.cache
      sed -e '/^FILE:@com_github_gperftools_gperftools/autom4te.cache.*/d' -i $bazelOut/external/\@*.marker
    '';

    postInstall = ''
      for d in $bazelOut/external/* ; do
        echo "$d $(nix-hash --type sha256 $d)"
      done
    '';

    sha256 = "9FSxeOtr6djIk060oEx0piwPa/6tjyg/28Si0a/JTFA=";
  };

  buildAttrs = {
    preBuild = toolchainPatch { inherit cmake ninja gnumake; } + preBuild + ''
      sed -i 's,#!/usr/bin/env bash,#!${stdenv.shell},' $bazelOut/external/rules_foreign_cc/tools/build_defs/framework.bzl

      patchShebangs $bazelOut/external/com_github_luajit_luajit/build.py

      # pass in the commit explicitly so it doesn't try to use git to find it out
      # this has to be the commit id and not any other string as it is passed to
      # the linker via --build-id
      cat > SOURCE_VERSION <<EOF
      ${src.rev}
      EOF

      sed -z -e 's;name = "zlib",\n\s*cache_entries = {;name = "zlib",\n\tcache_entries = {\n\t\t"CMAKE_MAKE_PROGRAM":"${ninja}/bin/ninja",;g' -i bazel/foreign_cc/BUILD
    '';

    installPhase = ''
      mkdir -p $out/bin
      mv bazel-bin/source/exe/envoy-static $out/bin/envoy
    '';
  };
}
