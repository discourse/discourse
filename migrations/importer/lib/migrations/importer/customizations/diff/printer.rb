# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Diff
        # The human-readable report.
        class Printer
          SHORT = 160

          def initialize(runner, full: false, output: $stdout)
            @runner = runner
            @report = runner.report
            @diffs = runner.diffs
            @full = full
            @output = output
          end

          def print
            puts "Tables compared: #{@runner.selected_count}, identical: #{@report[:identical].size}, " \
                   "differing: #{@diffs.size}, skipped: #{@report[:skipped].size}, " \
                   "too large: #{@report[:too_large].size}"
            puts

            print_summary
            @diffs.each { |diff| print_table(diff) }
            print_uploads
            print_too_large
            print_skipped
          end

          def self.truncate(value, full)
            return "NULL" if value.nil?
            return value.inspect if full || value.length <= SHORT
            "#{value[0, 150].inspect}… (#{value.length} chars)"
          end

          # Long text (theme CSS, JSON blobs) is shown as the differing middle only.
          def self.snippet_diff(before, after, full)
            if full || before.nil? || after.nil? ||
                 (before.length <= SHORT && after.length <= SHORT)
              return "#{truncate(before, full)} => #{truncate(after, full)}"
            end

            prefix = 0
            prefix += 1 while prefix < before.length && prefix < after.length &&
              before[prefix] == after[prefix]
            suffix = 0
            while suffix < before.length - prefix && suffix < after.length - prefix &&
                    before[-1 - suffix] == after[-1 - suffix]
              suffix += 1
            end

            context = 30
            from = [prefix - context, 0].max
            b = before[from, (before.length - suffix - from) + context]
            a = after[from, (after.length - suffix - from) + context]
            lead = from > 0 ? "…" : ""
            trail_b = (before.length - suffix) + context < before.length ? "…" : ""
            trail_a = (after.length - suffix) + context < after.length ? "…" : ""
            "(#{before.length} -> #{after.length} chars, differs at #{prefix}) " \
              "#{lead}#{b.inspect}#{trail_b} => #{lead}#{a.inspect}#{trail_a}"
          end

          private

          def puts(line = nil)
            @output.puts(line)
          end

          def print_summary
            return if @diffs.empty?

            puts "Summary"
            puts "-------"
            width = @diffs.map { |d| d.table.length }.max
            @diffs.each do |d|
              puts format(
                     "%-#{width}s  +%-5d -%-5d ~%-5d (ignored-only: %d)",
                     d.table,
                     d.added.size,
                     d.removed.size,
                     d.changed.size,
                     d.ignored_only,
                   )
            end
            puts
          end

          def print_table(d)
            return if d.added.empty? && d.removed.empty? && d.changed.empty?

            key_label = d.keyed? ? d.key_columns.join(",") : "no primary key, whole row"
            filter = @report[:tables][d.table][:where]
            puts "== #{d.table} (key: #{key_label}#{filter ? "; rows where #{filter}" : ""})"
            if (mismatch = @report[:schema_mismatch][d.table])
              puts "   schema differs; compared common columns only " \
                     "(before-only: #{mismatch[:only_in_before].join(",")}; " \
                     "after-only: #{mismatch[:only_in_after].join(",")})"
            end

            d.added.each { |row| print_row("+", d, row) }
            d.removed.each { |row| print_row("-", d, row) }
            d.changed.each do |c|
              puts "  ~ #{c[:key].join(",")}#{name_label(d.row_hash(c[:after]))}"
              c[:diffs].each do |col, (b, a)|
                puts "      #{col}: #{self.class.snippet_diff(b, a, @full)}"
              end
            end
            puts
          end

          def print_row(sign, d, row)
            puts "  #{sign} #{d.keyed? ? d.key_of(row).join(",") : "(whole row)"}"
            d
              .row_hash(row)
              .each do |col, val|
                puts "      #{col}: #{self.class.truncate(val, @full)}" unless val.nil?
              end
          end

          # Ids alone don't say which setting or group changed.
          def name_label(row_hash)
            name = row_hash["name"] || row_hash["translation_key"] || row_hash["slug"]
            name ? " (#{name})" : ""
          end

          def print_uploads
            uploads = @report[:uploads]
            return if uploads.empty?

            puts "Uploads referenced by added/changed rows (resolved in after)"
            puts "-------------------------------------------------------------"
            uploads
              .sort_by { |id, _| id.to_i }
              .each do |id, u|
                puts "  #{id}: #{u["original_filename"]} (#{u["filesize"]} bytes) #{u["url"]}"
              end
            missing = @runner.upload_ids.to_a - uploads.keys.map(&:to_i)
            puts "  not found in after: #{missing.sort.join(", ")}" if missing.any?
            puts
          end

          def print_too_large
            return if @report[:too_large].empty?

            puts "Differing but too large to diff row by row (raise --max-rows or use --only)"
            @report[:too_large].each { |t, c| puts "  #{t}: #{c[:before]} -> #{c[:after]} rows" }
            puts
          end

          def print_skipped
            changed_skipped = @report[:skipped].select { |_, c| c[:before] != c[:after] }
            return if changed_skipped.empty?

            puts "Skipped tables whose row count changed"
            changed_skipped.each { |t, c| puts "  #{t}: #{c[:before]} -> #{c[:after]} rows" }
            puts
          end
        end
      end
    end
  end
end
