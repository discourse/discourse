# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"

module Migrations
  module Converters
    module MarkdownEngine
      # The ordered JavaScript a `Context` evaluates: the host application's
      # precompiled pretty-text bundle (built out of process by
      # `frontend/pretty-text-processor`), the supported plugins' vendored
      # libraries and markdown features (the latter transpiled through the
      # host's `AssetProcessor`), and the generated emoji replacement table.
      #
      # Cached on disk keyed by a digest of every input. On a cache miss the
      # build runs in a SUBPROCESS that writes the cache and exits, because
      # transpiling the plugin features boots `AssetProcessor`'s own V8 and V8
      # initialized multithreaded is not fork-safe — the converter parent forks
      # workers, so it must never hold V8 state, nor the Rails/Discourse
      # stand-ins the host build code needs ({HostShims}). A warm cache needs
      # neither node nor pnpm.
      class Bundle
        class BuildError < StandardError
        end

        # Bump when the entry list or generation logic changes in a way the
        # input files cannot express.
        VERSION = 2

        CACHE_DIR = "tmp/migrations"

        # What the bundled plugins register as `:vendored_pretty_text` /
        # `:vendored_core_pretty_text` assets; plugin feature modules reference
        # these as plain globals.
        PLUGIN_VENDOR_FILES = %w[
          frontend/discourse/node_modules/moment/moment.js
          frontend/discourse/node_modules/moment-timezone/builds/moment-timezone-with-data.js
          plugins/footnote/assets/vendor/javascripts/markdown-it-footnote.js
        ].freeze

        # Every plugin bundled with the host application whose markdown features
        # change tokenization. Their constructs must tokenize the way the
        # destination will see them, or text inside e.g. a `[poll]` or `$$…$$`
        # would be scanned as ordinary prose and a mention in there would be
        # replaced. The set is fixed, not configuration: `Config::SETTING_KEYS`
        # covers exactly these plugins' parse-relevant settings, so a plugin
        # outside the list would run its markdown rules with absent settings. A
        # drift spec compares this list against the plugins that actually ship
        # markdown files. discourse-ai is the one deliberate exclusion: its
        # markdown modules only allowlist HTML attributes and register no rules.
        CORE_MARKDOWN_PLUGINS = %w[
          chat
          checklist
          discourse-details
          discourse-events
          discourse-graphviz
          discourse-local-dates
          discourse-math
          discourse-policy
          footnote
          poll
          spoiler-alert
        ].freeze

        # Digesting reads the host constants and file globs only, so no V8 boots
        # here and the host classes stay Rails-free.
        def self.load_or_build(cache_dir: nil)
          root = MarkdownEngine.discourse_root
          cache_dir ||= File.join(root, CACHE_DIR)
          # rubocop:disable Discourse/NoChdir
          Dir.chdir(root) do
            require_host_build_classes(root)

            digest = input_digest(root)
            cache_file = File.join(cache_dir, "markdown-engine-bundle-#{digest}.json")
            entries = read_cache(cache_file)
            return new(entries) if entries

            FileUtils.mkdir_p(cache_dir)
            File.open(File.join(cache_dir, "bundle.lock"), File::CREAT | File::RDWR) do |lock|
              lock.flock(File::LOCK_EX)
              # Another process may have built while this one waited.
              entries = read_cache(cache_file)
              unless entries
                build_in_subprocess(root, cache_file)
                entries = read_cache(cache_file)
                if entries.nil?
                  raise BuildError, "bundle build subprocess produced no readable cache"
                end
              end
              cleanup_stale_caches(cache_dir, cache_file)
            end
            new(entries)
          end
          # rubocop:enable Discourse/NoChdir
        end

        # Run this only in the separate process that `load_or_build` spawns, for
        # the reason in the class comment. Writes via temp file and atomic
        # rename, so a crashed build cannot leave a truncated cache another run
        # trusts.
        def self.build_and_write(root, cache_file)
          # discourse-emojis decides whether to load its railtie by checking for
          # `Rails`, so it must load before the stand-in exists.
          require "discourse_emojis"
          require "mini_racer"
          HostShims.install!(root)
          # rubocop:disable Discourse/NoChdir
          Dir.chdir(root) do
            require_host_build_classes(root)

            entries = build_entries(root)
            FileUtils.mkdir_p(File.dirname(cache_file))
            temp_file = "#{cache_file}.#{Process.pid}.tmp"
            begin
              File.write(temp_file, JSON.generate({ "entries" => entries }))
              File.rename(temp_file, cache_file)
            ensure
              File.delete(temp_file) if File.exist?(temp_file)
            end
          end
          # rubocop:enable Discourse/NoChdir
        end

        # A missing file, a truncated or corrupt one, and valid JSON with the
        # wrong shape are all cache misses; without the shape check,
        # `{"entries":"corrupt"}` would reach the context and raise there
        # instead of rebuilding. An empty list is a miss too: no build produces
        # zero entries.
        def self.read_cache(cache_file)
          entries = JSON.parse(File.read(cache_file))["entries"]
          return nil unless entries.is_a?(Array)
          return nil if entries.empty?
          return nil unless entries.all? { |entry| entry_pair?(entry) }

          entries
        rescue Errno::ENOENT, JSON::ParserError
          nil
        end

        def self.entry_pair?(entry)
          entry.is_a?(Array) && entry.size == 2 && entry.all?(String)
        end

        def self.build_in_subprocess(root, cache_file)
          program =
            "require \"migrations-converters\"; " \
              "Migrations::Converters::MarkdownEngine::Bundle.build_and_write(ARGV[0], ARGV[1])"
          _stdout, stderr, status =
            Open3.capture3(RbConfig.ruby, "-e", program, root, cache_file, chdir: root)
          return if status.success?

          raise BuildError, "bundle build subprocess failed: #{stderr.strip}"
        end

        # @return [Array<Array(String, String)>] `[module_name, source]` pairs
        attr_reader :entries

        def initialize(entries)
          @entries = entries
        end

        # `AssetProcessor` references `PrecompiledBundle` in its class body, so
        # the load order matters. A booted application has both already.
        def self.require_host_build_classes(root)
          return if Object.const_defined?(:AssetProcessor)

          require File.join(root, "lib", "precompiled_bundle")
          require File.join(root, "lib", "asset_processor")
          require File.join(root, "lib", "pretty_text", "core_bundle")
        end

        def self.input_digest(root)
          digest = Digest::MD5.new
          digest.update("v#{VERSION}")
          digest.update("compiler-v#{::AssetProcessor::BASE_COMPILER_VERSION}")
          digest_globs(digest, root, ::AssetProcessor::BUNDLE.dependency_globs)
          digest_globs(digest, root, core_bundle_globs)

          (input_files(root) + EmojiData.data_files).each do |path|
            digest.update(path)
            digest.update(File.read(path))
          end
          digest.hexdigest
        end

        def self.digest_globs(digest, root, globs)
          globs.each do |pattern|
            Dir
              .glob(pattern, base: root)
              .sort
              .each do |file|
                digest.update(file)
                digest.update(File.read(File.join(root, file)))
              end
          end
        end

        def self.input_files(root)
          files = PLUGIN_VENDOR_FILES.map { |path| File.join(root, path) }
          CORE_MARKDOWN_PLUGINS.each { |plugin| files.concat(plugin_files(root, plugin)) }
          files
        end

        def self.plugin_files(root, plugin)
          pattern =
            File.join(
              root,
              "plugins",
              plugin,
              "assets/javascripts/**/discourse-markdown/**/*.{js,js.es6}",
            )
          Dir[pattern].sort.filter { |path| File.file?(path) }
        end

        # The host's own definition, so there is one bundle: a booted
        # application shares this object with `PrettyText` and the same cache
        # file; standalone, the host stand-ins carry its build block.
        def self.host_core_bundle
          require_host_build_classes(MarkdownEngine.discourse_root)
          ::PrettyText::CoreBundle::BUNDLE
        end

        # @return [Array<String>] the dependency globs of the host core bundle,
        #   the JavaScript sources the produced context is built from
        def self.core_bundle_globs
          host_core_bundle.dependency_globs
        end

        def self.build_entries(root)
          entries = [["pretty-text.js", host_core_bundle.load_or_build]]

          PLUGIN_VENDOR_FILES.each { |path| entries << [path, File.read(File.join(root, path))] }

          CORE_MARKDOWN_PLUGINS.each do |plugin|
            plugin_files(root, plugin).each do |path|
              # Feature discovery only pattern-matches the `discourse/plugins/`
              # prefix and the file name, so the directory name can stand in for
              # the plugin's registered name.
              module_name =
                path.sub(%r{\A.+assets/javascripts/}, "discourse/plugins/#{plugin}/").sub(
                  /\.js(\.es6)?\z/,
                  "",
                )
              entries << transpiled_entry(path, module_name)
            end
          end

          entries << ["migrations/emoji-data", EmojiData.set_unicode_source]
          entries
        end

        def self.transpiled_entry(path, module_name)
          source = File.read(path)
          [module_name, ::AssetProcessor.new.perform(source, nil, module_name)]
        end

        # Runs under the build lock, so no concurrent starter can be reading a
        # stale file as it disappears.
        def self.cleanup_stale_caches(cache_dir, current_file)
          Dir[File.join(cache_dir, "markdown-engine-bundle-*.json")].each do |path|
            File.delete(path) if path != current_file
          end
        end

        private_class_method :input_digest,
                             :digest_globs,
                             :input_files,
                             :plugin_files,
                             :host_core_bundle,
                             :build_entries,
                             :transpiled_entry,
                             :entry_pair?,
                             :cleanup_stale_caches,
                             :read_cache,
                             :build_in_subprocess,
                             :require_host_build_classes
      end
    end
  end
end
