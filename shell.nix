{ mkShell, envoy }:

mkShell {
  name = "envoy-env";

  buildInputs = [ envoy ];
}
