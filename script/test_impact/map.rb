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

    INDEXES = %w[settings keys locales reads].freeze

    SETTINGS_FILE = %r{\A(?:config/site_settings\.yml|plugins/[^/]+/config/settings\.yml)\z}
    LOCALE_FILE = %r{\A(?:plugins/[^/]+/)?config/locales/server\.([A-Za-z_]+)\.yml\z}

    def self.build(recording_paths)
      specs = []
      spec_ids = {}
      ranges = Hash.new { |h, path| h[path] = Hash.new { |r, range| r[range] = Set.new } }
      methods = Hash.new { |h, path| h[path] = Set.new }
      seconds = Hash.new(0.0)
      indexes = INDEXES.to_h { |kind| [kind, Hash.new { |h, name| h[name] = Set.new }] }

      recording_paths.each do |path|
        Zlib::GzipReader.open(path) do |gz|
          gz.each_line do |line|
            entry = JSON.parse(line)
            if entry["methods"]
              entry["methods"].each { |file, list| methods[file].merge(list) }
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
      (ranges.keys | methods.keys).each do |file|
        files[file] = {
          "methods" => methods[file].to_a.sort,
          "ranges" => ranges[file].map { |range, ids| [*range, ids.to_a.sort] }.sort,
        }
      end
      new(
        "specs" => specs,
        "seconds" => specs.each_index.map { |id| seconds[id].round(2) },
        "files" => files,
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
    end

    def dump(path)
      Zlib::GzipWriter.open(path) { |gz| gz.write(JSON.generate(@data)) }
    end

    def spec_count
      @specs.size
    end

    # Recorded run time of the given spec files (all of them by default), in
    # seconds.
    def seconds(spec_paths = @specs)
      times = @data["seconds"] || []
      ids = @spec_ids ||= @specs.each_with_index.to_h
      spec_paths.sum { |spec| (id = ids[spec]) ? times[id].to_f : 0.0 }
    end

    # Changed spec files are selected as they are. A hunk in a recorded file
    # selects the specs that ran the methods it touches; one that touches no
    # method and nothing that ran (constants, associations, validations: code
    # that only runs at load) selects every spec that ran the file. A method
    # no spec ran selects nothing and is reported as untested.
    #
    # A hunk in a settings file selects the specs that read the setting it is
    # in, and one in a server locale file the specs that looked up its key (or
    # a key above or below it), in that locale unless it is English, which
    # every locale falls back to. Other files select the specs that read them.
    #
    # `source` returns a changed file's content before the change, for the
    # settings and keys its hunks fall in.
    def select(changes, source: ->(_path) {})
      ids = Set.new
      specs = Set.new
      unmapped = []
      untested = []

      changes.each do |change|
        path = change.new_path || change.old_path
        if path.end_with?("_spec.rb")
          specs << change.new_path if change.new_path
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
          next
        end

        file = old && @files[old]
        if !file
          readers = @indexes["reads"][old]
          readers ? ids.merge(readers) : unmapped << path
          next
        end
        # A rename or mode change: the constant's path is what moved.
        if change.hunks.empty?
          file["ranges"].each { |_, _, spec_ids| ids.merge(spec_ids) }
          next
        end
        change.hunks.each do |first, last|
          touched = file["methods"].select { |s, e| s <= last && e >= first }
          windows = touched.empty? ? [[first, last]] : touched
          reached = file["ranges"].select { |s, e, _| windows.any? { |ws, we| s <= we && e >= ws } }
          if reached.any?
            reached.each { |_, _, spec_ids| ids.merge(spec_ids) }
          elsif touched.any?
            untested << "#{old}:#{first}-#{last}"
          else
            file["ranges"].each { |_, _, spec_ids| ids.merge(spec_ids) }
          end
        end
      end

      specs.merge(ids.map { |id| @specs[id] })
      Selection.new(specs: specs.to_a.sort, unmapped: unmapped.uniq.sort, untested: untested)
    end

    private

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

  module Diff
    Change = Struct.new(:old_path, :new_path, :hunks, keyword_init: true)

    # `git diff -U0` output: each file's old path, new path (nil when added
    # or deleted) and the old-side line range of each hunk. A pure insertion
    # covers the lines on either side of it.
    def self.parse(text)
      changes = []
      text.each_line(chomp: true) do |line|
        case line
        when %r{\Adiff --git a/(.+) b/(.+)\z}
          changes << Change.new(old_path: $1, new_path: $2, hunks: [])
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
  end
end
