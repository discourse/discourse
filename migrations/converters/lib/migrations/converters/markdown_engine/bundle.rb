# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"

module Migrations
  module Converters
    module MarkdownEngine
      # The ordered JavaScript a `Context` evaluates: the host application's
      # precompiled pretty-text bundle (pretty-text, discourse-markdown-it,
      # and the allowlisted application modules, built out of process by
      # `frontend/pretty-text-processor`), the configured plugins' vendored
      # libraries and markdown features (the latter transpiled through the
      # host's `AssetProcessor`), and the generated emoji replacement table.
      #
      # Cached on disk keyed by a digest of every input. On a cache miss the
      # build runs in a SUBPROCESS that writes the cache and exits: the
      # pretty-text bundle is built by an external node command, but
      # transpiling the plugin features boots `AssetProcessor`'s own V8, and
      # V8 initialized multithreaded is not fork-safe — the converter parent
      # forks workers, so it must never hold V8 state (nor the Rails/Discourse
      # stand-ins the host build code needs, which would otherwise contaminate
      # the process; see {HostShims}). The parent only computes the digest and
      # reads JSON; workers only evaluate. A warm cache needs neither node nor
      # pnpm.
      class Bundle
        class BuildError < StandardError
        end

        # Bump when the entry list or generation logic changes in a way the
        # input files cannot express.
        VERSION = 2

        CACHE_DIR = "tmp/migrations"

        # Mirrors `PrettyText::BUNDLED_DISCOURSE_MODULES` and the dependency
        # globs of `PrettyText::CORE_BUNDLE`. Inside a booted application the
        # host bundle is used directly; standalone, an identical twin is built
        # under the host stand-ins — `PrettyText` itself cannot load there
        # (it requires gems the converter doesn't carry). The rails parity job
        # asserts the mirror matches the host definition, and the parity spec
        # surfaces any drift in the produced context regardless.
        BUNDLED_DISCOURSE_MODULES = %w[
          deprecation-workflow
          lib/avatar-utils
          lib/case-converter
          lib/escape
          lib/get-url
          lib/object
          loader
          static/markdown-it/features
        ].freeze

        CORE_BUNDLE_GLOBS =
          (
            %w[
              node_modules/.pnpm/lock.yaml
              frontend/pretty-text-processor/**/*.{js,mjs,cjs,json}
              frontend/pretty-text/addon/**/*.js
              frontend/discourse-markdown-it/src/**/*.js
            ] + BUNDLED_DISCOURSE_MODULES.map { |m| "frontend/discourse/app/#{m}.js" }
          ).freeze

        # What the bundled plugins register as `:vendored_pretty_text` /
        # `:vendored_core_pretty_text` assets (see each plugin.rb and
        # `DiscoursePluginRegistry::VENDORED_CORE_PRETTY_TEXT_MAP`): plugin
        # feature modules reference these as plain globals.
        PLUGIN_VENDOR_FILES = %w[
          frontend/discourse/node_modules/moment/moment.js
          frontend/discourse/node_modules/moment-timezone/builds/moment-timezone-with-data.js
          plugins/footnote/assets/vendor/javascripts/markdown-it-footnote.js
        ].freeze

        # The supported plugins: the ones bundled with the host application
        # that ship markdown features. Their constructs must tokenize the way
        # the destination will see them, or text inside e.g. a `[poll]` would
        # be scanned as ordinary prose. This list is an allowlist, not open
        # configuration: `Config::SETTING_KEYS` covers exactly these plugins'
        # parse-relevant settings (a spec checks that per plugin), so a name
        # outside the list would run its markdown rules with absent settings —
        # `validate_plugins!` rejects it instead. A source that relied on such
        # a plugin is scanned without its rules; that is the engine's
        # accuracy boundary.
        CORE_MARKDOWN_PLUGINS = %w[
          chat
          checklist
          discourse-details
          discourse-local-dates
          footnote
          poll
          spoiler-alert
        ].freeze

        # Digesting reads the host constants and file globs only; V8 boots on
        # a transpile, which never happens in this process, and the host
        # classes are Rails-free until their build/transpile methods run.
        #
        # @param plugins [Array<String>] a subset of {CORE_MARKDOWN_PLUGINS};
        #   any other name raises `ArgumentError` (see the list's comment).
        def self.load_or_build(
          root: MarkdownEngine.discourse_root,
          cache_dir: nil,
          plugins: CORE_MARKDOWN_PLUGINS
        )
          plugins = validate_plugins!(plugins)
          cache_dir ||= File.join(root, CACHE_DIR)
          # rubocop:disable Discourse/NoChdir
          Dir.chdir(root) do
            require_host_build_classes(root)

            digest = input_digest(root, plugins)
            cache_file = File.join(cache_dir, "markdown-engine-bundle-#{digest}.json")
            entries = read_cache(cache_file)
            return new(entries) if entries

            FileUtils.mkdir_p(cache_dir)
            File.open(File.join(cache_dir, "bundle.lock"), File::CREAT | File::RDWR) do |lock|
              lock.flock(File::LOCK_EX)
              # Another process may have built while this one waited.
              entries = read_cache(cache_file)
              unless entries
                build_in_subprocess(root, cache_file, plugins)
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

        # The build itself. Run this only in the separate process that
        # `load_or_build` spawns: it initializes V8 and installs the host
        # stand-ins, and neither may live in the forking converter parent.
        # Writes via temp file and atomic rename, so a crashed build cannot
        # leave a truncated cache another run would trust.
        def self.build_and_write(root, cache_file, plugins: CORE_MARKDOWN_PLUGINS)
          plugins = validate_plugins!(plugins)
          # discourse-emojis decides whether to load its railtie by checking
          # for `Rails`, so it must load before the Rails stand-in exists.
          require "discourse_emojis"
          require "mini_racer"
          HostShims.install!(root)
          # rubocop:disable Discourse/NoChdir
          Dir.chdir(root) do
            require_host_build_classes(root)

            entries = build_entries(root, plugins)
            FileUtils.mkdir_p(File.dirname(cache_file))
            temp_file = "#{cache_file}.#{Process.pid}.tmp"
            begin
              File.write(temp_file, JSON.generate({ "entries" => entries }))
              File.rename(temp_file, cache_file)
            ensure
              # A failed write or rename must not leave the temporary file
              # behind.
              File.delete(temp_file) if File.exist?(temp_file)
            end
          end
          # rubocop:enable Discourse/NoChdir
        end

        # A missing file, a truncated or corrupt one, and valid JSON with the
        # wrong shape are all cache misses. Without the shape check,
        # `{"entries":"corrupt"}` would reach the context and raise a
        # NoMethodError there instead of rebuilding. An empty list is a miss
        # too: no build produces zero entries, so it can only be a damaged
        # file, and evaluating it would give a context with no engine at all.
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

        def self.build_in_subprocess(root, cache_file, plugins)
          program =
            "require \"migrations-converters\"; " \
              "Migrations::Converters::MarkdownEngine::Bundle.build_and_write(" \
              "ARGV[0], ARGV[1], plugins: ARGV[2].to_s.split(\",\"))"
          _stdout, stderr, status =
            Open3.capture3(
              RbConfig.ruby,
              "-e",
              program,
              root,
              cache_file,
              plugins.join(","),
              chdir: root,
            )
          return if status.success?

          raise BuildError, "bundle build subprocess failed: #{stderr.strip}"
        end

        # @return [Array<Array(String, String)>] `[module_name, source]` pairs
        attr_reader :entries

        def initialize(entries)
          @entries = entries
        end

        # `AssetProcessor` references `PrecompiledBundle` in its class body,
        # so the load order matters; a booted application has both already.
        def self.require_host_build_classes(root)
          return if Object.const_defined?(:AssetProcessor)

          require File.join(root, "lib", "precompiled_bundle")
          require File.join(root, "lib", "asset_processor")
        end

        def self.input_digest(root, plugins)
          digest = Digest::MD5.new
          digest.update("v#{VERSION}")
          digest.update("compiler-v#{::AssetProcessor::BASE_COMPILER_VERSION}")
          # The list itself is an input: the same files with a different
          # configured set must build a different bundle.
          digest.update("plugins-#{plugins.join(",")}")
          digest_globs(digest, root, ::AssetProcessor::BUNDLE.dependency_globs)
          digest_globs(digest, root, CORE_BUNDLE_GLOBS)

          (input_files(root, plugins) + EmojiData.data_files).each do |path|
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

        def self.input_files(root, plugins)
          files = PLUGIN_VENDOR_FILES.map { |path| File.join(root, path) }
          plugins.each { |plugin| files.concat(plugin_files(root, plugin)) }
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

        # In a booted application the host's own bundle is reused (same cache,
        # same build); standalone — only ever the build subprocess — the
        # mirror builds an identical file under the host stand-ins.
        def self.core_bundle_source(root)
          if Object.const_defined?(:PrettyText)
            ::PrettyText.load_or_build_core_bundle
          else
            core_bundle_mirror.load_or_build
          end
        end

        def self.core_bundle_mirror
          ::PrecompiledBundle.new(
            dir: "tmp/pretty-text-processor",
            filename_prefix: "pretty-text",
            dependency_globs: CORE_BUNDLE_GLOBS,
          ) do
            ::Discourse::Utils.execute_command(
              "pnpm",
              "-C=frontend/pretty-text-processor",
              "node",
              "build.mjs",
              "--discourse-modules=#{BUNDLED_DISCOURSE_MODULES.join(",")}",
              chdir: ::Rails.root.to_s,
            )
          end
        end

        def self.build_entries(root, plugins)
          entries = [["pretty-text.js", core_bundle_source(root)]]

          PLUGIN_VENDOR_FILES.each { |path| entries << [path, File.read(File.join(root, path))] }

          plugins.each do |plugin|
            plugin_files(root, plugin).each do |path|
              # The directory name stands in for the plugin's registered name;
              # feature discovery only pattern-matches the `discourse/plugins/`
              # prefix and the file name, so the middle segment is free-form.
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
        # stale file while it disappears.
        def self.cleanup_stale_caches(cache_dir, current_file)
          Dir[File.join(cache_dir, "markdown-engine-bundle-*.json")].each do |path|
            File.delete(path) if path != current_file
          end
        end

        # Called from both public entry points: `build_and_write` runs in its
        # own subprocess and can be invoked directly, so it cannot rely on
        # `load_or_build` having validated. Returns the normalized list —
        # deduplicated (a doubled name would bundle the plugin twice and
        # change the cache digest) and frozen against later mutation.
        def self.validate_plugins!(plugins)
          unknown = plugins - CORE_MARKDOWN_PLUGINS
          unless unknown.empty?
            raise ArgumentError,
                  "unsupported markdown plugins: #{unknown.join(", ")} " \
                    "(supported: #{CORE_MARKDOWN_PLUGINS.join(", ")})"
          end

          plugins.uniq.freeze
        end

        private_class_method :validate_plugins!,
                             :input_digest,
                             :digest_globs,
                             :input_files,
                             :plugin_files,
                             :core_bundle_source,
                             :core_bundle_mirror,
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
