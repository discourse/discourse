# frozen_string_literal: true

# Static assets are immutable for the lifetime of a test run (a single
# digest-stamped Ember build) but are served without a Cache-Control header,
# so Chromium re-validates every script chunk on each cold navigation. The
# soft-resetting Playwright driver keeps one browser context (and therefore
# one HTTP cache) alive per worker; an explicit max-age turns each example's
# first-navigation asset burst into pure cache hits instead of a queue of
# conditional GETs against the in-process Puma server.
#
# Server-GENERATED code documents must NOT be stored, in spite of (and
# precisely because of) the `immutable_for(1.year)` their controllers stamp
# on digest URLs: those digests are not pure content functions across
# examples. `fab!`/`let_it_be` reuses record ids between examples while the
# data rolls back, so e.g. the color-scheme stylesheet digest (keyed on
# scheme id + version, not content) names different CSS in different
# examples under the identical URL, and `ExtraLocalesController.js_digests`
# is a process-level memo that fabricated TranslationOverride rows never
# invalidate. With a worker-lifetime browser cache, an `immutable` response
# stored by one example gets served stale to a later one — `no-store` on
# every generated code response makes that class of leak impossible by
# construction. Everything else (HTML, JSON, images, avatars, uploads) keeps
# its current headers: image URLs are content-addressed or version-stamped,
# and HTML/JSON carry no cache headers today.
class StaticAssetCacheControl
  # Disk files emitted at most once per run: the digest-stamped Ember build
  # under /assets, vendored libraries under /javascripts.
  STATIC_BUILD_PATH = %r{\A(?:/[a-z0-9_-]+)?/(?:assets|javascripts)/}

  # Compiled stylesheets, extra-locales bundles, svg sprites, theme
  # javascripts, highlight-js bundles, webmanifest.
  GENERATED_CODE_TYPES = %r{text/css|javascript|image/svg|manifest}

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    if STATIC_BUILD_PATH.match?(env["PATH_INFO"].to_s)
      headers["Cache-Control"] = "public, max-age=3600" if status == 200
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
