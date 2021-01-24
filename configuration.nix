{ lib, config, pkgs, ... }:
let
  cfg = config.services.envoy;
  configYaml = pkgs.writeText "config.yaml" ''
    ${cfg.config}
  '';
in
with lib; {
  options.services.envoy = {
    enable = mkOption {
      default = false;
    };

    package = mkOption {
      type = types.package;
      default = pkgs.envoy;
    };

    config = mkOption {
      type = types.str;
      description = ''
        YAML config
      '';
      default = ''
        static_resources:
          listeners:
          clusters:
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    users = {
      users.envoy = {
        createHome = false;
        group = "envoy";
        uid = 16666;
      };
      groups.envoy.gid = 16666;
    };
    boot.kernel.sysctl = {
      "fs.inotify.max_user_watches" = 1048576;
    };
    systemd.services.envoy = {
      description = "Envoy proxy";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      wants = [ "network.target" ];

      path = [ cfg.package ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/envoy -c ${configYaml}";
        User = "envoy";
        Group = "envoy";
        WorkingDirectory = cfg.package;
        Type = "simple";
        StandardOutput = "journal";
        StandardError = "journal";
        Restart = "always";
        RestartSec = 1;

        LimitNOFILE = "infinity";

        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];

        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        ProtectHome = "yes";
        ProtectSystem = "strict";
        ProtectProc = "invisible";
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        PrivateDevices = true;
        PrivateTmp = true;
        SystemCallArchitectures = "native";
      };
      unitConfig = {
        StartLimitIntervalSec = 3;
        StartLimitBurst = 0;
      };
    };
  };
}
