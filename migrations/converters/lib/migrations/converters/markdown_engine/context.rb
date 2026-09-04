# frozen_string_literal: true

require "json"
require "mini_racer"

module Migrations
  module Converters
    module MarkdownEngine
      # One V8 engine per worker process. V8 contexts do not survive forking, so
      # a context is created after fork (a worker step's `setup`) and a fork
      # hook discards any instance a child accidentally inherits.
      class Context
        class DiscardedError < StandardError
        end

        # PrettyText allows 25s because it renders; a scan only parses. The
        # slowest legitimate parse we measured on a large corpus was 435 ms, so
        # 3 seconds has plenty of headroom while it keeps one runaway body from
        # dominating V8 time. A body the ceiling cuts off gets one retry with a
        # larger ceiling (`EngineScanner::SLOW_TIMEOUT_MS`), not a refusal.
        EVAL_TIMEOUT_MS = 3_000

        # @return [Config] the source-site inputs this engine was built from,
        #   for a caller that needs the name sets beside the engine
        attr_reader :config

        def initialize(bundle:, config:)
          @bundle = bundle
          @config = config
          @timeout_ms = EVAL_TIMEOUT_MS
          @needs_rebuild = false
          @monitor = Mutex.new
          @watchdog_signal = ConditionVariable.new
          @fork_hook = ForkManager.after_fork_child { discard! }
          build_context(@timeout_ms)
        end

        # @param posts [Array<Hash>] `{ id:, raw: }` per post
        # @param timeout_ms [Integer, nil] a one-off ceiling for this scan.
        #   MiniRacer fixes an isolate's timeout at construction, so the isolate
        #   keeps the widest ceiling it was asked for (a rebuild costs about
        #   0.15s) and anything below that is enforced by {#with_ceiling} — a
        #   caller counting a per-body deadline down must not pay for a rebuild
        #   per call.
        # @return [Array<Hash>] per-post block/construct data from scan.js
        def scan(posts, timeout_ms: nil)
          wanted = timeout_ms || @timeout_ms
          if @context.nil?
            raise DiscardedError unless @needs_rebuild
            build_context(wanted)
          elsif wanted > @ceiling_ms
            dispose_context
            build_context(wanted)
          end

          payload =
            posts.map do |post|
              raw = post[:raw].to_s
              raw = raw.scrub unless raw.valid_encoding?
              { "id" => post[:id], "raw" => raw }
            end
          with_ceiling(wanted) { @context.call("__scanPosts", payload) }
        end

        # A timeout can leave arbitrary JS state behind, so the context goes and
        # is rebuilt lazily on the next scan.
        def reset!
          dispose_context
          @needs_rebuild = true
        end

        def close
          dispose_context
          @needs_rebuild = false
          stop_watchdog

          if @fork_hook
            ForkManager.remove_after_fork_child(@fork_hook)
            @fork_hook = nil
          end
        end

        # Runs in a freshly forked child: the inherited isolate belongs to the
        # parent and must not be used or disposed from here, so only the
        # reference is dropped — and no lazy rebuild either, a worker builds its
        # own context deliberately.
        def discard!
          @context = nil
          @needs_rebuild = false
          # Threads do not survive a fork, and a lock the watchdog held while
          # the parent forked would still be held here.
          @monitor = Mutex.new
          @watchdog_signal = ConditionVariable.new
          @watchdog = nil
          @deadline = nil
        end

        private

        def build_context(timeout_ms)
          @context = MiniRacer::Context.new(timeout: timeout_ms, ensure_gc_after_idle: 2000)
          @ceiling_ms = timeout_ms
          @needs_rebuild = false
          evaluate_all(@bundle, @config)
        end

        # Disposal races the watchdog thread, which must not reach for a context
        # that is going away.
        def dispose_context
          @monitor.synchronize do
            @context&.dispose
            @context = nil
          end
        end

        # A ceiling below the isolate's own is enforced from a helper thread:
        # `MiniRacer::Context#stop` terminates the running script the way V8's
        # own watchdog does, so the caller sees the same `ScriptTerminatedError`
        # either way.
        def with_ceiling(timeout_ms)
          return yield if timeout_ms >= @ceiling_ms

          arm_watchdog(timeout_ms)
          terminated = false
          begin
            yield
          rescue MiniRacer::ScriptTerminatedError
            terminated = true
            raise
          ensure
            # The watchdog can fire between the script finishing and the disarm,
            # and V8 keeps an undelivered termination request for its next entry
            # — so the isolate goes rather than a later scan being cut short by
            # it.
            reset! if disarm_watchdog && !terminated
          end
        end

        def arm_watchdog(timeout_ms)
          @monitor.synchronize do
            @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_ms / 1000.0
            @fired = false
            @watchdog ||= Thread.new { watch }
            @watchdog_signal.signal
          end
        end

        # @return [Boolean] whether the watchdog terminated the script
        def disarm_watchdog
          @monitor.synchronize do
            @deadline = nil
            @fired
          end
        end

        def stop_watchdog
          watchdog = nil
          @monitor.synchronize do
            @closing = true
            watchdog = @watchdog
            @watchdog = nil
            @watchdog_signal.signal
          end
          watchdog&.join
        end

        # Sleeps until the armed deadline, an earlier disarm, or `close`. The
        # monitor is held only between waits, never while a script runs.
        def watch
          @monitor.synchronize do
            until @closing
              if @deadline.nil?
                @watchdog_signal.wait(@monitor)
                next
              end

              remaining = @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
              if remaining > 0
                @watchdog_signal.wait(@monitor, remaining)
              else
                @deadline = nil
                @fired = true
                begin
                  @context&.stop
                rescue MiniRacer::ContextDisposedError
                  # Raced a disposal that beat this thread to the monitor.
                  nil
                end
              end
            end
          end
        end

        def evaluate_all(bundle, config)
          # The environment the loaded modules expect.
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
              categorySlugs: #{config.category_lookup_slugs.to_h { |slug| [slug, true] }.to_json},
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
        # installs its callback surface and the unicode replacer into the
        # options it is given, so priming it with an empty string reuses that
        # assembly.
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
