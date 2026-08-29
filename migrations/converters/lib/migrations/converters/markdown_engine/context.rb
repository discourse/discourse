# frozen_string_literal: true

require "json"
require "mini_racer"

module Migrations
  module Converters
    module MarkdownEngine
      # One V8 engine per worker process. V8 contexts do not survive forking,
      # so a context is created after fork (a worker step's `setup`) and a fork
      # hook discards any instance a child process accidentally inherits.
      class Context
        class DiscardedError < StandardError
        end

        # PrettyText allows 25s because it renders; a scan only parses. The
        # slowest legitimate parse we measured on a large corpus was 435 ms,
        # so 3 seconds has plenty of headroom while it keeps one runaway body
        # from dominating V8 time. A body the ceiling cuts off gets one retry
        # with a larger ceiling (see `EngineScanner`) instead of a refusal.
        EVAL_TIMEOUT_MS = 3_000

        def initialize(bundle:, config:)
          @bundle = bundle
          @config = config
          @timeout_ms = EVAL_TIMEOUT_MS
          @needs_rebuild = false
          @fork_hook = ForkManager.after_fork_child { discard! }
          build_context(@timeout_ms)
        end

        # @param posts [Array<Hash>] `{ id:, raw: }` per post
        # @param timeout_ms [Integer, nil] a one-off ceiling for this scan,
        #   for a caller retrying a body that ran into the default. MiniRacer
        #   fixes the timeout at construction, so switching ceilings rebuilds
        #   the isolate (about 0.15s) — fine, because retries are rare — and
        #   the next default-ceiling scan rebuilds back the same way.
        # @return [Array<Hash>] per-post block/construct data from scan.js
        def scan(posts, timeout_ms: nil)
          wanted = timeout_ms || @timeout_ms
          if @context.nil?
            raise DiscardedError unless @needs_rebuild
            build_context(wanted)
          elsif @current_timeout_ms != wanted
            @context.dispose
            build_context(wanted)
          end

          payload =
            posts.map do |post|
              raw = post[:raw].to_s
              raw = raw.scrub unless raw.valid_encoding?
              { "id" => post[:id], "raw" => raw }
            end
          @context.call("__scanPosts", payload)
        end

        # Throws the V8 state away after a per-input engine failure (a timeout
        # can leave arbitrary JS state behind) and rebuilds lazily on the next
        # scan — the caller keeps one healthy engine without knowing when it
        # was last replaced.
        def reset!
          @context&.dispose
          @context = nil
          @needs_rebuild = true
        end

        def close
          @context&.dispose
          @context = nil
          @needs_rebuild = false

          if @fork_hook
            ForkManager.remove_after_fork_child(@fork_hook)
            @fork_hook = nil
          end
        end

        # Runs in a freshly forked child: the inherited isolate belongs to the
        # parent and must not be used or disposed from here, so only the
        # reference is dropped — no lazy rebuild either, a worker builds its
        # own context deliberately. The hook stays registered process-wide and
        # is cleaned up by `close`.
        def discard!
          @context = nil
          @needs_rebuild = false
        end

        private

        def build_context(timeout_ms)
          @context = MiniRacer::Context.new(timeout: timeout_ms, ensure_gc_after_idle: 2000)
          @current_timeout_ms = timeout_ms
          @needs_rebuild = false
          evaluate_all(@bundle, @config)
        end

        def evaluate_all(bundle, config)
          # Environment expected by the loaded modules; console output has no
          @context.eval(<<~JS, filename: "migrations/prelude.js")
            window = globalThis;
            window.devicePixelRatio = 2;
            console = { log() {}, warn() {}, error() {} };
            __PRETTY_TEXT = true;
          JS

          # The pretty-text bundle captures `globalThis.__Ruby` while it
          # evaluates, so the scan-mode stubs must exist before the entries.
          @context.eval(
            File.read(File.join(__dir__, "runtime.js")),
            filename: "migrations/runtime.js",
          )
          bundle.entries.each { |name, source| @context.eval(source, filename: name) }

          @context.eval(<<~JS, filename: "migrations/scan-config.js")
            __scanConfig = {
              categorySlugs: #{config.category_slugs.to_h { |slug| [slug, true] }.to_json},
              tagNames: #{config.tag_names.to_h { |name| [name, true] }.to_json}
            };
          JS

          @context.eval(options_source(config), filename: "migrations/options.js")
          @context.eval(File.read(File.join(__dir__, "scan.js")), filename: "migrations/scan.js")
          @context.low_memory_notification
        end

        # Mirrors the option construction in `PrettyText.markdown`, with
        # scan-mode values: no watched words (target-site config, unknown at
        # conversion time), no censoring, empty paths. `__PrettyText.cook`
        # installs its callback surface (routed to the `__Ruby` stubs from
        # runtime.js) and the unicode replacer into the options it is given —
        # priming it with an empty string reuses that assembly instead of
        # duplicating it, then the persistent engine is built from the
        # completed options exactly the way cook builds its own.
        def options_source(config)
          <<~JS
            __optInput = {
              siteSettings: #{config.settings.to_json},
              allowedIframes: #{config.settings["allowed_iframes"].to_s.split("|").to_json},
              paths: { baseUri: "" },
              customEmoji: #{config.custom_emoji.to_json},
              customEmojiTranslation: {},
              emojiDenyList: [],
              censoredRegexp: [],
              watchedWordsReplace: null,
              watchedWordsLink: null,
              additionalOptions: #{config.additional_options.to_json},
              avatar_sizes: #{config.avatar_sizes.to_json},
              hashtagTypesInPriorityOrder: ["category", "tag"],
              hashtagIcons: { category: "folder", tag: "tag" }
            };
            __PrettyText.cook("", __optInput);
            __pt = require("discourse-markdown-it").default
              .withCustomFeatures(require("discourse/static/markdown-it/features").default())
              .withOptions(__optInput);
          JS
        end
      end
    end
  end
end
