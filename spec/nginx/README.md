# nginx sample config tests

The system spec at `spec/system/nginx_sample_proxy_spec.rb` starts nginx in
front of the normal Capybara Rails server and points the browser at it. This
exercises `config/nginx.sample.conf` using the same application server as the
rest of the system test suite.

## Running

```sh
bin/rspec spec/system/nginx_sample_proxy_spec.rb
```

## Requirements

- `nginx` on `$PATH` for the system spec.
- Standard nginx 1.x. The spec skips when nginx isn't installed. Set
  `NGINX_BIN` to test with a specific executable.

## How it works

The helper rewrites only the deployment-specific ports and filesystem paths
into a temporary directory, then runs the real sample config as a subprocess.
Brotli directives are disabled because that optional module is not available
in every development nginx build.

## CI

The spec runs with the regular core system specs.
