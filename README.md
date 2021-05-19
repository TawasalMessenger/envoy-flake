# Configure

```nix
{
# ...
  services.envoy = {
    enable = true;
    config = ''
      admin:
        access_log_path: /tmp/admin_access.log
        address:
          socket_address: { address: 0.0.0.0, port_value: 9901 }

      static_resources:
        listeners:
        - name: listener_0
          address:
            socket_address: { address: 0.0.0.0, port_value: 8080 }
          filter_chains:
          - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                codec_type: auto
                stat_prefix: ingress_http
                route_config:
                  name: local_route
                  virtual_hosts:
                  - name: local_service
                    domains: ["*"]
                    routes:
                    - match: { prefix: "/" }
                      route:
                        cluster: echo_service
                        max_stream_duration:
                          grpc_timeout_header_max: 0s
                    cors:
                      allow_origin_string_match:
                      - prefix: "*"
                      allow_methods: GET, PUT, DELETE, POST, OPTIONS
                      allow_headers: keep-alive,user-agent,cache-control,content-type,content-transfer-encoding,custom-header-1,x-accept-content-transfer-encoding,x-accept-response-streaming,x-user-agent,x-grpc-web,grpc-timeout
                      max_age: "1728000"
                      expose_headers: custom-header-1,grpc-status,grpc-message
                http_filters:
                - name: envoy.filters.http.grpc_web
                - name: envoy.filters.http.cors
                - name: envoy.filters.http.router
        clusters:
        - name: echo_service
          connect_timeout: 0.25s
          type: logical_dns
          http2_protocol_options: {}
          lb_policy: round_robin
          load_assignment:
            cluster_name: cluster_0
            endpoints:
            - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: localhost
                      port_value: 9090
    '';
  };
# ...
}
```
