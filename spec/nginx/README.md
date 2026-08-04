# nginx sample config tests

These specs exercise `config/nginx.sample.conf` by spawning a real nginx
subprocess in front of a tiny WEBrick mock upstream, then sending HTTP
requests through nginx and asserting on what gets forwarded.

The goal is twofold: catch regressions when the sample config changes,
and serve as executable documentation of nginx behaviors that are
currently implicit.

## Running

```sh
spec/nginx/run.sh                       # runs the whole suite
spec/nginx/run.sh --example "basic"     # filter by name
spec/nginx/run.sh spec/nginx/foo_spec.rb # one file
```

The runner explicitly passes `--options /dev/null` so rspec ignores the
project's root `.rspec` (which auto-requires `rails_helper`). These
specs are Rails-free.

## Requirements

- `nginx` on `$PATH`. On NixOS: `nix-shell -p nginx --run spec/nginx/run.sh`.
- Standard nginx 1.x. Optional modules (e.g. `brotli`) are detected at
  setup; if missing, directives that depend on them are commented out of
  the test config and tests that specifically need those modules skip
  themselves via `Nginx::Support::ConfigRenderer.module_available?`.

If nginx isn't available, pure-Ruby support specs still run while
integration examples that need nginx are skipped with a warning. Set
`NGINX_TESTS_REQUIRED=1` in CI to make a missing nginx a failure
instead.

## How it works

Each example spins up:

1. A WEBrick server on a random port that runs `MockUpstream`, a Rack
   app that echoes the request as JSON (method, path, headers, body).
   Tests can ask it for specific responses via `X-Mock-*` request
   headers — see `support/mock_upstream.rb`.
2. An nginx subprocess on another random port, configured by
   `ConfigRenderer` to use the mock as its upstream.

`ConfigRenderer` reads the real `config/nginx.sample.conf`, substitutes
the handful of deployment-specific references (hardcoded `127.0.0.1:3000`
upstream, `/var/nginx/cache`, `/var/log/nginx/...`, the
`conf.d/outlets/...` includes), and writes the result plus a tiny
events+http wrapper into a tmpdir. The point is to keep the substituted
config as close to the actual sample as possible — every directive in
the sample should be exercised.

## Adding a test

```ruby
require "json"

RSpec.describe "nginx static asset handling" do
  let(:harness) { Nginx::Support::NginxHarness.new }

  before { harness.start }
  after { harness.stop }

  it "serves files under /assets/ from disk without touching the upstream" do
    asset = File.join(harness.tmpdir, "public/assets/foo.txt")
    FileUtils.mkdir_p(File.dirname(asset))
    File.write(asset, "hello")

    response = harness.get("/assets/foo.txt")
    expect(response.body).to eq("hello")
  end
end
```

For per-test response shaping from the mock upstream:

```ruby
response = harness.get("/some/path", headers: {
  "X-Mock-Status" => "503",
  "X-Mock-Header-Retry-After" => "30",
})
```

## CI

Runs as a dedicated GitHub Actions workflow
(`.github/workflows/nginx-tests.yml`) triggered when
`config/nginx.sample.conf`, `spec/nginx/**`, or the workflow file
itself change. Uses the `discourse/discourse_test:release` image, so
the nginx under test is the same build (including brotli) that ships
to production. `NGINX_TESTS_REQUIRED=1` is set in CI so a missing nginx
is a hard failure rather than a silent skip.
