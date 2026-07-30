# nginx sample config tests

The system spec at `spec/system/nginx_sample_proxy_spec.rb` exercises
`config/nginx.sample.conf` by spawning a real nginx subprocess in front of
the Capybara Rails server. It sends both direct HTTP requests and a browser
request through nginx.

The goal is twofold: catch regressions when the sample config changes,
and serve as executable documentation of nginx behaviors that are
currently implicit.

## Running

```sh
bin/rspec spec/system/nginx_sample_proxy_spec.rb # integration tests
bin/rspec spec/lib/nginx                        # support unit tests
```

## Requirements

- `nginx` on `$PATH` for the system spec.
- Standard nginx 1.x. Optional modules (e.g. `brotli`) are detected at
  setup; if missing, directives that depend on them are commented out of
  the test config.

The system spec skips when nginx isn't installed. The support unit tests do
not require an installed nginx.

## How it works

Each system example spins up:

1. A Capybara server on a random port running the real Rails application,
   wrapped in `NginxTestProbe`. The probe records selected requests and can
   add controlled response headers.
2. An nginx subprocess on another random port, configured by
   `ConfigRenderer` to use Rails as its upstream.

`ConfigRenderer` reads the real `config/nginx.sample.conf`, substitutes
the handful of deployment-specific references (hardcoded `127.0.0.1:3000`
upstream, `/var/nginx/cache`, `/var/log/nginx/...`, the
`conf.d/outlets/...` includes), and writes the result plus a tiny
events+http wrapper into a tmpdir. The point is to keep the substituted
config as close to the actual sample as possible — every directive in
the sample should be exercised.

## CI

The integration spec runs with the regular core system specs, using the
`discourse/discourse_test:release` image and its production nginx build. The
support unit tests run with the regular backend specs.
