# frozen_string_literal: true

require "json"
require "zlib"

module TestImpact
  # Which spec files ran which line ranges of each file, built from the
  # recorder's recordings, and the specs a diff's hunks reach.
  class Map
    Selection = Struct.new(:specs, :unmapped, :untested, keyword_init: true)

    def self.build(recording_paths)
      specs = []
      spec_ids = {}
      ranges = Hash.new { |h, path| h[path] = Hash.new { |r, range| r[range] = Set.new } }
      methods = Hash.new { |h, path| h[path] = Set.new }

      recording_paths.each do |path|
        Zlib::GzipReader.open(path) do |gz|
          gz.each_line do |line|
            entry = JSON.parse(line)
            if entry["methods"]
              entry["methods"].each { |file, list| methods[file].merge(list) }
              next
            end
            id = spec_ids[entry["spec"]] ||= (specs << entry["spec"]).size - 1
            entry["files"].each { |file, list| list.each { |range| ranges[file][range] << id } }
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
      new("specs" => specs, "files" => files)
    end

    def self.load(path)
      new(JSON.parse(Zlib::GzipReader.open(path, &:read)))
    end

    def initialize(data)
      @specs = data["specs"]
      @files = data["files"]
    end

    def dump(path)
      Zlib::GzipWriter.open(path) do |gz|
        gz.write(JSON.generate("specs" => @specs, "files" => @files))
      end
    end

    def spec_count
      @specs.size
    end

    # Changed spec files are selected as they are. A hunk in a recorded file
    # selects the specs that ran the methods it touches; one that touches no
    # method and nothing that ran (constants, associations, validations: code
    # that only runs at load) selects every spec that ran the file. A method
    # no spec ran selects nothing and is reported as untested.
    def select(changes)
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
        file = change.old_path && @files[change.old_path]
        if !file
          unmapped << path
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
            untested << "#{change.old_path}:#{first}-#{last}"
          else
            file["ranges"].each { |_, _, spec_ids| ids.merge(spec_ids) }
          end
        end
      end

      specs.merge(ids.map { |id| @specs[id] })
      Selection.new(specs: specs.to_a.sort, unmapped: unmapped.uniq.sort, untested: untested)
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
