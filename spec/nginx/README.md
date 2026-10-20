# nginx sample config tests

The integration spec at `spec/integration/nginx_sample_proxy_spec.rb` starts
nginx in front of a Capybara Rails server. This exercises
`config/nginx.sample.conf` against the real application without treating
nginx configuration behavior as a browser interaction.

## Running

```sh
bin/rspec spec/integration/nginx_sample_proxy_spec.rb
```

## Requirements

- `nginx` on `$PATH` for the integration spec.
- Standard nginx 1.x. The spec skips when nginx isn't installed. Set
  `NGINX_BIN` to test with a specific executable.

## How it works

The helper rewrites only the deployment-specific ports and filesystem paths
into a temporary directory, then runs the real sample config as a subprocess.
Brotli directives are disabled because that optional module is not available
in every development nginx build.

The test also installs a temporary outlet inside `location @discourse`, so it
can verify that dynamic requests use the normal Rails fallback.
