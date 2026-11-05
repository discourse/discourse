# frozen_string_literal: true

require "json"
require "zlib"

module TestImpact
  # What each spec file depended on, built from the recorder's recordings:
  # the line ranges it ran of each file, the settings it read, the translation
  # keys and locales it looked up, the data files it read. And the specs a
  # diff's hunks reach.
  class Map
    Selection = Struct.new(:specs, :unmapped, :untested, keyword_init: true)

    INDEXES = %w[settings keys locales reads tables gems].freeze

    SETTINGS_FILE = %r{\A(?:config/site_settings\.yml|plugins/[^/]+/config/settings\.yml)\z}
    LOCALE_FILE = %r{\A(?:plugins/[^/]+/)?config/locales/server\.([A-Za-z_]+)\.yml\z}
    QUNIT_TEST =
      %r{\A(?:frontend/[^/]+/tests|plugins/[^/]+/test|(?:tmp/)?themes/[^/]+/test)/.*-test\.g?[jt]s\z}
    # Dependency changes can change any code path.
    DEPENDENCIES =
      %r{\A(?:Gemfile(?:\.lock)?|pnpm-lock\.yaml|pnpm-workspace\.yaml|(?:.+/)?package\.json)\z}
    MIGRATION = %r{\A(?:plugins/[^/]+/)?db/(?:post_)?migrate/[^/]+\.rb\z}
    # Test support no test ran, documentation, which runs nowhere, type tests,
    # which only the type checker reads, and the schema dump: the test
    # database is migrated, and CI checks the dump in a step of its own. Also
    # what the Tests workflow ignores or never runs: the migrations tooling,
    # import and benchmark scripts, linter and editor configuration.
    NOT_RUN =
      %r{
        \A(?:
          frontend/[^/]+/(?:tests|type-tests)/ | plugins/[^/]+/test/ | docs/ | db/structure\.sql\z |
          migrations/ | script/(?:import_scripts|bulk_import|benchmarks)/ | bin/qunit\z |
          \.devcontainer/ | \.github/(?:labeler|dependabot)\.yml\z | CODEOWNERS\z |
          \.rubocop\.yml\z | eslint\.config\.mjs\z
        ) | (?:\A|/)\.gitignore\z | \.md\z
      }x
    # Files that run without other code naming them, so a new one can
    # change what existing specs do.
    LOADED_BY_CONVENTION =
      %r{\Aconfig/initializers/|/(?:pre-|instance-|api-)?initializers/|/connectors/|-route-map\.g?[jt]s\z}
    JS_SOURCE = /\.g?[jt]s\z/

    # `commit` is the commit the recordings ran on, whose line numbers the map
    # has.
    def self.build(recording_paths, commit: nil)
      specs = []
      spec_ids = {}
      ranges = Hash.new { |h, path| h[path] = Hash.new { |r, range| r[range] = Set.new } }
      methods = Hash.new { |h, path| h[path] = Set.new }
      boot = Hash.new { |h, path| h[path] = Set.new }
      gems = Hash.new { |h, kind| h[kind] = Set.new }
      seconds = Hash.new(0.0)
      indexes = INDEXES.to_h { |kind| [kind, Hash.new { |h, name| h[name] = Set.new }] }

      recording_paths.each do |path|
        Zlib::GzipReader.open(path) do |gz|
          gz.each_line do |line|
            entry = JSON.parse(line)
            if entry["methods"]
              entry["methods"].each { |file, list| methods[file].merge(list) }
              Hash(entry["boot"]).each { |file, list| boot[file].merge(list) }
              Hash(entry["gems"]).each { |kind, names| gems[kind].merge(names) }
              next
            end
            id = spec_ids[entry["spec"]] ||= (specs << entry["spec"]).size - 1
            seconds[id] += entry["seconds"].to_f
            entry["files"].each { |file, list| list.each { |range| ranges[file][range] << id } }
            INDEXES.each { |kind| Array(entry[kind]).each { |name| indexes[kind][name] << id } }
          end
        end
      end

      files = {}
      (ranges.keys | methods.keys | boot.keys).each do |file|
        files[file] = {
          "methods" => methods[file].to_a.sort,
          "boot" => boot[file].to_a.sort,
          "ranges" => ranges[file].map { |range, ids| [*range, ids.to_a.sort] }.sort,
        }
      end
      new(
        "commit" => commit,
        "specs" => specs,
        "seconds" => specs.each_index.map { |id| seconds[id].round(2) },
        "files" => files,
        "gem_sets" => gems.transform_values { |names| names.to_a.sort },
        **indexes.transform_values { |index| index.transform_values { |ids| ids.to_a.sort } },
      )
    end

    def self.load(path)
      new(JSON.parse(Zlib::GzipReader.open(path, &:read)))
    end

    def initialize(data)
      @data = data
      @specs = data["specs"]
      @files = data["files"]
      @indexes = INDEXES.to_h { |kind| [kind, data[kind] || {}] }
      @gem_sets = (data["gem_sets"] || {}).transform_values(&:to_set)
    end

    def dump(path)
      Zlib::GzipWriter.open(path) { |gz| gz.write(JSON.generate(@data)) }
    end

    # The commit the map's line numbers are from, if it was built with one.
    def commit
      @data["commit"]
    end

    def spec_count
      @specs.size
    end

    # The spec and test files the map recorded.
    def specs
      @specs
    end

    # Recorded run time of the given spec files (all of them by default), in
    # seconds.
    def seconds(spec_paths = @specs)
      times = @data["seconds"] || []
      ids = @spec_ids ||= @specs.each_with_index.to_h
      spec_paths.sum { |spec| (id = ids[spec]) ? times[id].to_f : 0.0 }
    end

    # Changed spec and QUnit test files are selected as they are. A hunk in a recorded file
    # selects the specs that ran the methods it touches; one that touches no
    # method and nothing that ran (constants, associations, validations: code
    # that only runs at load) selects every spec that ran the file. A method
    # no spec ran selects nothing and is reported as untested.
    #
    # A hunk in a settings file selects the specs that read the setting it is
    # in, and one in a server locale file the specs that looked up its key (or
    # a key above or below it), in that locale unless it is English, which
    # every locale falls back to; either also selects the specs that read the
    # file. Other files select the specs that read them. Test support,
    # documentation and type tests no spec ran or read select nothing, and so
    # does deleting a file no spec loaded or read. Dependency changes, and
    # changes to methods that ran at boot, are reported as outside the map. A
    # migration selects the specs that queried the tables it names. A new file
    # selects the specs that read files beside it and is reported as untested,
    # unless it runs by convention, which is outside the map.
    #
    # `source` returns a changed file's content before the change, for the
    # settings and keys its hunks fall in. `translate` takes a recorded file
    # and hunks in the base's line numbers and returns them in the map's, for a
    # base other than the commit the map was recorded at (Diff.translator).
    def select(changes, source: ->(_path) {}, translate: ->(_path, hunks) { hunks })
      ids = Set.new
      specs = Set.new
      unmapped = []
      untested = []

      changes = pair_conversions(changes)
      changes.each do |change|
        path = change.new_path || change.old_path
        if path.end_with?("_spec.rb") || QUNIT_TEST.match?(path)
          specs << change.new_path if change.new_path
          next
        end

        if path == "Gemfile.lock" && @gem_sets.any? && change.old_path &&
             (lines = source.call(change.old_path))
          reached = gems_reached(gems_changed(lines.lines, change.hunks, change.added))
          reached ? ids.merge(reached) : unmapped << path
          ids.merge(@indexes["reads"][path] || [])
          next
        end

        if DEPENDENCIES.match?(path)
          unmapped << path
          next
        end

        if MIGRATION.match?(path)
          touched =
            tables_named([change.added, change.old_path && source.call(change.old_path)].join("\n"))
          touched.empty? ? unmapped << path : ids.merge(touched)
          next
        end

        old = change.old_path
        lines = old && (SETTINGS_FILE.match?(old) || LOCALE_FILE.match?(old)) && source.call(old)
        if lines
          lines = lines.lines
          reached =
            if SETTINGS_FILE.match?(old)
              settings_reached(lines, change.hunks)
            else
              keys_reached(lines, change.hunks, old[LOCALE_FILE, 1])
            end
          reached ? ids.merge(reached) : unmapped << path
          # Specs that read the file whole, not only the settings or keys in it.
          ids.merge(@indexes["reads"][old] || [])
          next
        end

        file = old && @files[old]
        if !old
          # A new file runs when something loads it: a change to existing
          # code, which selects its own specs, or a new spec. What loads
          # files by globbing their directory read the ones beside it.
          if LOADED_BY_CONVENTION.match?(path)
            unmapped << path
          else
            ids.merge(sibling_readers(path))
            untested << "#{path}: new, selected through what loads it" if !NOT_RUN.match?(path)
          end
          next
        end
        # A map recorded after a rename landed knows the file by its new path,
        # where the old side's line numbers don't apply.
        renamed = !file && change.new_path != old && @files[change.new_path]
        file ||= renamed
        if !file
          readers = @indexes["reads"][old]
          if readers
            ids.merge(readers)
          elsif change.new_path && !NOT_RUN.match?(path)
            unmapped << path
          end
          next
        end
        # A rename or mode change: the constant's path is what moved.
        if change.hunks.empty? || renamed
          file["ranges"].each { |_, _, spec_ids| ids.merge(spec_ids) }
          next
        end
        translate
          .call(old, change.hunks)
          .each do |first, last|
            touched = file["methods"].select { |s, e| s <= last && e >= first }
            # JavaScript functions nest (closures, classes, module wrappers):
            # what a hunk changes is the innermost ones it falls in.
            innermost =
              touched.reject do |s, e|
                touched.any? { |ts, te| [ts, te] != [s, e] && ts >= s && te <= e }
              end
            # Boot ran it before any spec, so no spec is charged with it.
            unmapped << path if innermost.any? { |range| file["boot"]&.include?(range) }
            if innermost.any?
              reached = file["ranges"].select { |s, e, _| innermost.include?([s, e]) }
              reached.each { |_, _, spec_ids| ids.merge(spec_ids) }
              untested << "#{old}:#{first}-#{last}" if reached.empty?
            end

            outside = (first..last).reject { |line| touched.any? { |s, e| line.between?(s, e) } }
            next if outside.empty?
            reached =
              file["ranges"].select { |s, e, _| outside.any? { |line| line.between?(s, e) } }
            reached = file["ranges"] if reached.empty?
            reached.each { |_, _, spec_ids| ids.merge(spec_ids) }
          end
      end

      specs.merge(ids.map { |id| @specs[id] })
      Selection.new(specs: specs.to_a.sort, unmapped: unmapped.uniq.sort, untested: untested)
    end

    private

    # A file converted between JavaScript and TypeScript changes too much
    # for git to see a rename: the deletion and addition become one.
    def pair_conversions(changes)
      deleted =
        changes
          .select { |c| !c.new_path && JS_SOURCE.match?(c.old_path) }
          .group_by { |c| c.old_path.sub(JS_SOURCE, "") }
          .transform_values(&:first)
      paired = []
      converted =
        changes.filter_map do |c|
          next c if c.old_path || !JS_SOURCE.match?(c.new_path)
          before = deleted[c.new_path.sub(JS_SOURCE, "")] or next c
          paired << before
          Diff::Change.new(
            old_path: before.old_path,
            new_path: c.new_path,
            hunks: [],
            added: c.added,
          )
        end
      converted - paired
    end

    def sibling_readers(path)
      dir = File.dirname(path)
      @indexes["reads"].each_with_object(Set.new) do |(read, ids), readers|
        readers.merge(ids) if File.dirname(read) == dir
      end
    end

    # The specs that queried a table a migration names, by name in its SQL or
    # its schema calls, or as a model class in a data change (`Post` for
    # posts). Over-selecting on a word that happens to be a table is fine.
    def tables_named(text)
      # Chat::Message is chat_messages.
      namespaced = text.scan(/\b[A-Z]\w*(?:::[A-Z]\w*)+/).map { |name| name.delete(":") }
      words = (text.scan(/\b[A-Za-z_]\w*\b/) + namespaced).uniq
      names =
        words.flat_map do |word|
          next [word] if word.match?(/\A[a-z_0-9]+\z/)
          next [] if !word.match?(/\A[A-Z][A-Za-z0-9]*\z/)
          snake = word.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
          [snake.sub(/y\z/, "ies"), snake.sub(/(s|x|ch|sh)\z/, '\1es'), "#{snake}s"]
        end
      names.uniq.flat_map { |name| @indexes["tables"][name] || [] }
    end

    # The gems whose entries a Gemfile.lock diff changes, or nil when it
    # changes anything else (Ruby version, platforms, Bundler, a git or path
    # source). A dependency line belongs to the gem above it.
    def gems_changed(lines, hunks, added)
      section = nil
      current = nil
      owners =
        lines.map do |line|
          section = line.strip if line.match?(/\A[A-Z]/)
          if line.strip.empty?
            :blank
          elsif !%w[GEM CHECKSUMS DEPENDENCIES].include?(section)
            nil
          elsif line.match?(/\A {6}\S/)
            current
          elsif line =~ /\A {2}(?: {2})?([\w.-]+)(?: \(.*|!)?\n?\z/
            current = $1
          end
        end
      touched = hunks.flat_map { |first, last| owners[(first - 1)...[last, lines.size].min] }
      touched.delete(:blank)
      return if touched.include?(nil)
      added = added.each_line.filter_map { |line| line[/\A {2}(?: {2})?([\w.-]+) \(/, 1] }
      (touched + added).to_set
    end

    # Specs that ran a changed gem. nil when one ran at boot or has a native
    # extension (whose C code Coverage doesn't see), or when it loaded but no
    # spec ran its methods. A gem the suite never loaded selects nothing.
    def gems_reached(gems)
      return if !gems
      loaded = gems.select { |gem| @gem_sets["loaded"]&.include?(gem) }
      unseen =
        loaded.any? do |gem|
          @gem_sets["boot"]&.include?(gem) || @gem_sets["native"]&.include?(gem) ||
            !@indexes["gems"][gem]
        end
      return if unseen
      loaded.flat_map { |gem| @indexes["gems"][gem] }.to_set
    end

    # nil when a hunk touches a category rather than a setting.
    def settings_reached(lines, hunks)
      paths = Yaml.key_paths(lines)
      names = hunk_paths(paths, hunks).map { |path| path&.split(".")&.[](1) }
      return if names.include?(nil)
      names.uniq.flat_map { |name| @indexes["settings"][name] || [] }
    end

    # nil when a hunk touches the locale's root.
    def keys_reached(lines, hunks, locale)
      paths = Yaml.key_paths(lines)
      keys = hunk_paths(paths, hunks).map { |path| path&.split(".", 2)&.[](1) }
      return if keys.include?(nil)
      reached =
        keys.uniq.flat_map do |key|
          @indexes["keys"].flat_map do |looked_up, spec_ids|
            related =
              looked_up == key || key.start_with?("#{looked_up}.") ||
                looked_up.start_with?("#{key}.")
            related ? spec_ids : []
          end
        end
      return reached if locale == "en"
      reached & (@indexes["locales"][locale] || [])
    end

    # The key path of each changed line that has one (blank and comment lines
    # have none).
    def hunk_paths(paths, hunks)
      hunks
        .flat_map { |first, last| (first..last).map { |line| paths[line - 1] } }
        .compact
        .then { |found| found.empty? ? [nil] : found }
    end
  end

  # Key paths of a YAML file's lines, by indentation: enough for the plain
  # nested mappings of settings and locale files.
  module Yaml
    KEY = /\A( *)(?:"([^"]+)"|'([^']+)'|([^\s#'"\-][^:#]*?)):(?:\s|\z)/
    BLOCK_SCALAR = /\A[|>][-+0-9]*\s*(?:#.*)?\z/

    def self.key_paths(lines)
      stack = []
      block_indent = nil
      lines.map do |line|
        indent = line[/\A */].size
        stripped = line.strip
        if block_indent
          next stack.map(&:last).join(".") if stripped.empty? || indent > block_indent
          block_indent = nil
        end
        next if stripped.empty? || stripped.start_with?("#")

        match = KEY.match(line)
        if match
          stack.pop while stack.any? && stack.last[0] >= indent
          stack << [indent, (match[2] || match[3] || match[4]).strip]
          rest = line[match.end(0)..].to_s.strip
          block_indent = indent if BLOCK_SCALAR.match?(rest)
        end
        stack.map(&:last).join(".")
      end
    end
  end

  # One job of .github/workflows/tests.yml, named BUILD_TYPE/TARGET, and what
  # it runs of a selection.
  class Job
    # bin/qunit filters by path in the test page's URL, which allows 8KB.
    QUNIT_FILTER_LIMIT = 7 * 1024

    def initialize(name)
      @build_type, @target = name.split("/", 2)
      @name = name
    end

    # ["full" | "none" | "list", reason, files]. `recorded` is every spec and
    # test file in the map: a job none of them belong to wasn't recorded.
    def run(selection, recorded:, bundled:, exists:)
      if selection.unmapped.any?
        return "full", "outside the map: #{selection.unmapped.first(5).join(", ")}", []
      end
      if recorded.none? { |path| runs?(path, bundled) }
        return "full", "the map records no tests for #{@name}", []
      end
      files = selection.specs.select { |path| exists.call(path) && runs?(path, bundled) }
      return "none", "nothing selected for #{@name}", [] if files.empty?
      if @build_type == "frontend" && files.sum { |file| file.size + 1 } > QUNIT_FILTER_LIMIT
        return "full", "#{files.size} test files are too many to filter by path", []
      end
      ["list", "#{files.size} of the job's files", files]
    end

    private

    def runs?(path, bundled)
      plugin = path[%r{\Aplugins/([^/]+)/}, 1]
      spec = path.end_with?("_spec.rb")
      system = path.start_with?("spec/system/") || path.include?("/spec/system/")
      case [@build_type, @target]
      in ["backend", "core"]
        spec && path.start_with?("spec/") && !system
      in ["backend", "plugins"]
        spec && plugin && !system
      in ["system", "core"]
        spec && path.start_with?("spec/system/")
      in ["system", "themes"]
        spec && system && path.match?(%r{\A(?:tmp/)?themes/})
      in ["system", "chat"]
        spec && plugin == "chat" && system
      in ["system", "core-plugins"]
        spec && system && bundled.include?(plugin) && plugin != "chat"
      in ["system", "official-plugins"]
        spec && system && plugin && !bundled.include?(plugin)
      in ["frontend", "core"]
        !spec && path.start_with?("frontend/")
      in ["frontend", "plugins"]
        !spec && plugin
      in ["frontend", "themes"]
        !spec && path.match?(%r{\A(?:tmp/)?themes/[^/]+/test/})
      end
    end
  end

  module Diff
    Change = Struct.new(:old_path, :new_path, :hunks, :added, keyword_init: true)

    # `git diff -U0` output: each file's old path, new path (nil when added
    # or deleted), the old-side line range of each hunk and the added lines'
    # text. A pure insertion covers the lines on either side of it.
    def self.parse(text)
      changes = []
      text.each_line(chomp: true) do |line|
        case line
        when %r{\Adiff --git a/(.+) b/(.+)\z}
          changes << Change.new(old_path: $1, new_path: $2, hunks: [], added: +"")
        when /\A\+/
          # Before the first hunk it's the +++ header.
          changes.last.added << line[1..] << "\n" if changes.last.hunks.any?
        when /\Anew file mode /
          changes.last.old_path = nil
        when /\Adeleted file mode /
          changes.last.new_path = nil
        when /\A@@ -(\d+)(?:,(\d+))? /
          start = $1.to_i
          count = ($2 || "1").to_i
          changes.last.hunks << (count == 0 ? [start, start + 1] : [start, start + count - 1])
        end
      end
      changes
    end

    # The working tree's changes since its merge base with `base` (so
    # uncommitted changes count too), and a reader of files at that base.
    def self.against(base)
      merge_base = IO.popen(["git", "merge-base", base, "HEAD"], &:read).strip
      raise "no merge base with #{base}" if !$?.success?
      diff = IO.popen(["git", "diff", "-U0", "--no-color", "-M", merge_base], &:read)
      raise "git diff failed" if !$?.success?
      source = ->(path) do
        IO.popen(["git", "show", "#{merge_base}:#{path}"], err: File::NULL, &:read)
      end
      [parse(diff), source, merge_base]
    end

    # For Map#select: moves hunks in `from`'s line numbers to `to`'s, through
    # the file's changes between the two.
    def self.translator(from, to)
      diffs = {}
      lambda do |path, hunks|
        diff =
          diffs[path] ||= IO
            .popen(["git", "diff", "-U0", "--no-color", from, to, "--", path], &:read)
            .scan(/^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/)
            .map do |old_first, old_count, new_first, new_count|
              [old_first.to_i, (old_count || "1").to_i, new_first.to_i, (new_count || "1").to_i]
            end
        hunks.map { |first, last| [line_in(first, diff, :first), line_in(last, diff, :last)] }
      end
    end

    # A line's number after `diff` ([old first, old count, new first, new
    # count] per hunk). A line the diff changed becomes the start or end of
    # what replaced it, so a range over it widens to cover all of that.
    def self.line_in(line, diff, side)
      shift = 0
      diff.each do |old_first, old_count, new_first, new_count|
        if old_count == 0
          # Lines added after old_first.
          break if old_first >= line
          shift += new_count
        elsif old_first + old_count - 1 < line
          shift += new_count - old_count
        elsif old_first <= line
          return side == :first ? new_first : new_first + [new_count, 1].max - 1
        else
          break
        end
      end
      line + shift
    end
  end
end
