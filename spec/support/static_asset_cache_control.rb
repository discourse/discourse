# frozen_string_literal: true

# Static assets are immutable for the lifetime of a test run (a single
# digest-stamped Ember build) but are served without a Cache-Control header,
# so Chromium re-validates every script chunk on each cold navigation. The
# soft-resetting Playwright driver keeps one browser context (and therefore
# one HTTP cache) alive per worker; an explicit max-age turns each example's
# first-navigation asset burst into pure cache hits instead of a queue of
# conditional GETs against the in-process Puma server.
#
# Server-GENERATED code documents whose digest URLs are NOT pure content
# functions must not be stored: with a worker-lifetime browser cache, an
# `immutable_for(1.year)` response stored by one example gets served stale
# to a later one when `fab!`/`let_it_be` id reuse plus the per-example
# rollback makes a digest collide across different content. `no-store` on
# those responses makes that leak impossible by construction.
#
# Three generated families are exempt because their digests ARE pure content
# functions and may keep the immutable headers their controllers stamp —
# this matters: the no-store round trips for stylesheets and extra-locales
# alone measure ~0.43s of in-process server time per navigation (~9 full
# Rails dispatches), all of it render- or boot-blocking browser-side:
#
# * /stylesheets — core targets (common/desktop/mobile/admin/wizard) digest
#   on cachebuster+plugins+hostname only; color_definitions_* and *_theme
#   digests are made content-keyed by generated_asset_digest_honesty.rb.
# * /extra-locales — digests are SHA1s of the bundle content itself; the
#   stale-memo hole for site-specific bundles is closed by
#   generated_asset_digest_honesty.rb.
# * /svg-sprite — the URL version is `Digest::SHA1.hexdigest(bundle)`,
#   content-addressed in stock code.
#
# Everything else (HTML, JSON, images, avatars, uploads) keeps its current
# headers: image URLs are content-addressed or version-stamped, and
# HTML/JSON carry no cache headers today.
class StaticAssetCacheControl
  # Disk files emitted at most once per run: the digest-stamped Ember build
  # under /assets, vendored libraries under /javascripts.
  STATIC_BUILD_PATH = %r{\A(?:/[a-z0-9_-]+)?/(?:assets|javascripts)/}

  # Generated code served under content-honest digest URLs (see above).
  CONTENT_ADDRESSED_PATHS = %r{\A(?:/[a-z0-9_-]+)?/(?:stylesheets|extra-locales|svg-sprite)/}

  # Remaining generated code: theme javascripts, highlight-js bundles,
  # webmanifest.
  GENERATED_CODE_TYPES = %r{text/css|javascript|image/svg|manifest}

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    path = env["PATH_INFO"].to_s
    if STATIC_BUILD_PATH.match?(path)
      headers["Cache-Control"] = "public, max-age=3600" if status == 200
    elsif CONTENT_ADDRESSED_PATHS.match?(path)
      # leave the controller-stamped headers (immutable_for on digest match)
    elsif GENERATED_CODE_TYPES.match?(headers["Content-Type"].to_s)
      headers["Cache-Control"] = "no-store"
    end
    [status, headers, body]
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    # `Capybara.app` is a mutable `Rack::Builder` only once
    # action_dispatch/system_test_case has been loaded (i.e. when system
    # specs are part of the run). Rebuild it with the middleware declared
    # before the `map` statement - `Rack::Builder#use` called after `map`
    # consumes the mapping and breaks the builder - while keeping the same
    # builder semantics `set_subfolder` relies on for live remapping.
    if Capybara.app.is_a?(Rack::Builder)
      Capybara.app =
        Rack::Builder.new do
          use StaticAssetCacheControl
          map "/" do
            run Rails.application
          end
        end
    end
  end
end
