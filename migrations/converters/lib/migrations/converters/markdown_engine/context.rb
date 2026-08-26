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

        # Mirrors PrettyText's context limits.
        EVAL_TIMEOUT_MS = 25_000

        def initialize(bundle:, config:)
          @context = MiniRacer::Context.new(timeout: EVAL_TIMEOUT_MS, ensure_gc_after_idle: 2000)
          @fork_hook = ForkManager.after_fork_child { discard! }
          evaluate_all(bundle, config)
        end

        # @param posts [Array<Hash>] `{ id:, raw: }` per post
        # @return [Array<Hash>] per-post block/construct data from scan.js
        def scan(posts)
          raise DiscardedError if @context.nil?

          payload =
            posts.map do |post|
              raw = post[:raw].to_s
              raw = raw.scrub unless raw.valid_encoding?
              { "id" => post[:id], "raw" => raw }
            end
          @context.call("__scanPosts", payload)
        end

        def close
          @context&.dispose
          @context = nil

          if @fork_hook
            ForkManager.remove_after_fork_child(@fork_hook)
            @fork_hook = nil
          end
        end

        # Runs in a freshly forked child: the inherited isolate belongs to the
        # parent and must not be used or disposed from here, so only the
        # reference is dropped. The hook stays registered process-wide and is
        # cleaned up by `close`.
        def discard!
          @context = nil
        end

        private

        def evaluate_all(bundle, config)
          # Environment expected by the loaded modules; console output has no
          # useful destination in a worker, so errors are collected for
          # debugging instead of being routed to a logger.
          @context.eval(<<~JS, filename: "migrations/prelude.js")
            window = globalThis;
            window.devicePixelRatio = 2;
            __consoleErrors = [];
            console = {
              log() {},
              warn() {},
              error(...args) { __consoleErrors.push(args.join(" ")); }
            };
            __PRETTY_TEXT = true;
          JS

          bundle.entries.each { |name, source| @context.eval(source, filename: name) }

          @context.eval(
            File.read(File.join(__dir__, "runtime.js")),
            filename: "migrations/runtime.js",
          )
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

        # Mirrors the `__optInput` construction in `PrettyText.markdown`, with
        # scan-mode values: no watched words (target-site config, unknown at
        # conversion time), no censoring, callbacks from runtime.js.
        def options_source(config)
          <<~JS
            __optInput = {};
            __optInput.siteSettings = #{config.settings.to_json};
            __optInput.allowedIframes = #{config.settings["allowed_iframes"].to_s.split("|").to_json};
            __optInput.getURL = __getURL;
            __optInput.getCurrentUser = __getCurrentUser;
            __optInput.lookupAvatar = __lookupAvatar;
            __optInput.lookupPrimaryUserGroup = __lookupPrimaryUserGroup;
            __optInput.formatUsername = __formatUsername;
            __optInput.getTopicInfo = __getTopicInfo;
            __optInput.hashtagLookup = __hashtagLookup;
            __optInput.customEmoji = #{config.custom_emoji.to_json};
            __optInput.customEmojiTranslation = {};
            __optInput.emojiUnicodeReplacer = __emojiUnicodeReplacer;
            __optInput.emojiDenyList = [];
            __optInput.lookupUploadUrls = __lookupUploadUrls;
            __optInput.censoredRegexp = [];
            __optInput.watchedWordsReplace = null;
            __optInput.watchedWordsLink = null;
            __optInput.additionalOptions = #{config.additional_options.to_json};
            __optInput.avatar_sizes = #{config.avatar_sizes.to_json};
            __optInput.hashtagTypesInPriorityOrder = ["category", "tag"];
            __optInput.hashtagIcons = { category: "folder", tag: "tag" };
            __pluginFeatures = __loadPluginFeatures();
            __pt = __DiscourseMarkdownIt.withCustomFeatures(__pluginFeatures).withOptions(__optInput);
          JS
        end
      end
    end
  end
end
