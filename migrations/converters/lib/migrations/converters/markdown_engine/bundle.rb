# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"

module Migrations
  module Converters
    module MarkdownEngine
      # The ordered JavaScript a `Context` evaluates: vendor libraries verbatim,
      # the pretty-text and discourse-markdown-it modules (plus the fixed list
      # of application helpers and the bundled plugins' markdown features)
      # transpiled through the host application's `AssetProcessor`, the host's
      # `shims.js`, and the generated emoji replacement table.
      #
      # Cached on disk keyed by a digest of every input. On a cache miss the
      # build runs in a SUBPROCESS that writes the cache and exits: transpiling
      # boots `AssetProcessor`'s own V8, and V8 initialized multithreaded is
      # not fork-safe — the converter parent forks workers, so it must never
      # hold V8 state (nor the Rails/Discourse stand-ins `AssetProcessor`
      # needs, which would otherwise contaminate the process; see {HostShims}).
      # The parent only computes the digest and reads JSON; workers only
      # evaluate. A warm cache needs neither node nor pnpm.
      class Bundle
        class BuildError < StandardError
        end
        # Bump when the entry list or generation logic changes in a way the
        # input files cannot express.
        VERSION = 1

        CACHE_DIR = "tmp/migrations"

        # Load order mirrors `PrettyText.create_es6_context`.
        VENDOR_FILES = %w[
          frontend/discourse/node_modules/loader.js/dist/loader/loader.js
          frontend/discourse-markdown-it/node_modules/markdown-it/dist/markdown-it.js
          frontend/discourse-markdown-it/node_modules/xss/dist/xss.js
          lib/pretty_text/vendor-shims.js
        ].freeze

        MODULE_DIRS = {
          "frontend/pretty-text/addon" => "pretty-text/",
          "frontend/discourse-markdown-it/src" => "discourse-markdown-it/",
        }.freeze

        APP_FILES = %w[
          discourse/app/deprecation-workflow
          discourse/app/lib/get-url
          discourse/app/lib/object
          discourse/app/lib/deprecated
          discourse/app/lib/escape
          discourse/app/lib/avatar-utils
          discourse/app/lib/case-converter
          discourse/app/lib/to-markdown
          discourse/app/static/markdown-it/features
        ].freeze

        SHIMS_FILE = "lib/pretty_text/shims.js"

        # What the bundled plugins register as `:vendored_pretty_text` /
        # `:vendored_core_pretty_text` assets (see each plugin.rb and
        # `DiscoursePluginRegistry::VENDORED_CORE_PRETTY_TEXT_MAP`): plugin
        # feature modules reference these as plain globals.
        PLUGIN_VENDOR_FILES = %w[
          frontend/discourse/node_modules/moment/moment.js
          frontend/discourse/node_modules/moment-timezone/builds/moment-timezone-with-data.js
          plugins/footnote/assets/vendor/javascripts/markdown-it-footnote.js
        ].freeze

        # The plugins bundled with the host application that ship markdown
        # features. A dev checkout can contain many additional plugins; the
        # target site cooks with exactly these, so the scan does too — their
        # constructs must tokenize the way the destination will see them, or
        # text inside e.g. a `[poll]` would be scanned as ordinary prose. This
        # is also an accuracy boundary: a source that relied on some other
        # plugin's markdown feature is scanned without it.
        CORE_MARKDOWN_PLUGINS = %w[
          chat
          checklist
          discourse-details
          discourse-local-dates
          footnote
          poll
          spoiler-alert
        ].freeze

        # AssetProcessor resolves its own cache and inputs with cwd-relative
        # globs, so digesting (and, in the build subprocess, building) must
        # happen at the application root — the same constraint PrettyText's
        # context creation has. Requiring `asset_processor` here is safe: the
        # digest only reads its constants and file globs; V8 boots only on a
        # transpile, which never happens in this process.
        def self.load_or_build(root: MarkdownEngine.discourse_root, cache_dir: nil)
          cache_dir ||= File.join(root, CACHE_DIR)
          # rubocop:disable Discourse/NoChdir
          Dir.chdir(root) do
            unless Object.const_defined?(:AssetProcessor)
              require File.join(root, "lib", "asset_processor")
            end

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

        # The build itself — run this only in a throwaway process (the
        # subprocess `load_or_build` spawns): it initializes V8 and installs
        # the host stand-ins, both of which must never live in the forking
        # converter parent. Writes via temp file + atomic rename so a crashed
        # build can never leave a truncated cache another run would trust.
        def self.build_and_write(root, cache_file)
          # discourse-emojis decides whether to load its railtie by checking
          # for `Rails`, so it must load before the Rails stand-in exists.
          require "discourse_emojis"
          require "mini_racer"
          HostShims.install!(root)
          # rubocop:disable Discourse/NoChdir
          Dir.chdir(root) do
            unless Object.const_defined?(:AssetProcessor)
              require File.join(root, "lib", "asset_processor")
            end

            entries = build_entries(root)
            FileUtils.mkdir_p(File.dirname(cache_file))
            temp_file = "#{cache_file}.#{Process.pid}.tmp"
            File.write(temp_file, JSON.generate({ "entries" => entries }))
            File.rename(temp_file, cache_file)
          end
          # rubocop:enable Discourse/NoChdir
        end

        # A missing file and a truncated/corrupt one (a writer killed before
        # the atomic-rename discipline existed, a partial copy) are both just
        # cache misses.
        def self.read_cache(cache_file)
          JSON.parse(File.read(cache_file))["entries"]
        rescue Errno::ENOENT, JSON::ParserError
          nil
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

        def self.input_digest(root)
          digest = Digest::MD5.new
          digest.update("v#{VERSION}")
          digest.update("compiler-v#{AssetProcessor::BASE_COMPILER_VERSION}")
          digest.update(AssetProcessor.inputs_digest)

          (input_files(root) + EmojiData.data_files).each do |path|
            digest.update(path)
            digest.update(File.read(path))
          end
          digest.hexdigest
        end

        def self.input_files(root)
          files = VENDOR_FILES.map { |path| File.join(root, path) }
          MODULE_DIRS.each_key { |dir| files.concat(Dir[File.join(root, dir, "**", "*.js")].sort) }
          APP_FILES.each { |path| files << File.join(root, "frontend", "#{path}.js") }
          PLUGIN_VENDOR_FILES.each { |path| files << File.join(root, path) }
          files << File.join(root, SHIMS_FILE)
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

        def self.build_entries(root)
          entries = []
          VENDOR_FILES.each { |path| entries << [path, File.read(File.join(root, path))] }

          MODULE_DIRS.each do |dir, module_prefix|
            base_path = File.join(root, dir)
            Dir["**/*.js", base: base_path].sort.each do |relative|
              module_name = "#{module_prefix}#{relative.delete_suffix(".js")}"
              entries << transpiled_entry(File.join(base_path, relative), module_name)
            end
          end

          APP_FILES.each do |path|
            module_name = path.sub("/app/", "/")
            entries << transpiled_entry(File.join(root, "frontend", "#{path}.js"), module_name)
          end

          PLUGIN_VENDOR_FILES.each { |path| entries << [path, File.read(File.join(root, path))] }

          CORE_MARKDOWN_PLUGINS.each do |plugin|
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

          entries << [SHIMS_FILE, File.read(File.join(root, SHIMS_FILE))]
          entries << ["migrations/emoji-data", EmojiData.set_unicode_source]
          entries
        end

        def self.transpiled_entry(path, module_name)
          source = File.read(path)
          [module_name, AssetProcessor.new.perform(source, nil, module_name)]
        end

        # Runs under the build lock, so no concurrent starter can be reading a
        # stale file while it disappears.
        def self.cleanup_stale_caches(cache_dir, current_file)
          Dir[File.join(cache_dir, "markdown-engine-bundle-*.json")].each do |path|
            File.delete(path) if path != current_file
          end
        end

        private_class_method :input_digest,
                             :input_files,
                             :plugin_files,
                             :build_entries,
                             :transpiled_entry,
                             :cleanup_stale_caches,
                             :read_cache,
                             :build_in_subprocess
      end
    end
  end
end
