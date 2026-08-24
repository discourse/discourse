# frozen_string_literal: true
RSpec::Support.require_rspec_core "formatters/base_text_formatter"
RSpec::Support.require_rspec_core "formatters/console_codes"

module TurboTests
  class BaseFormatter < RSpec::Core::Formatters::BaseTextFormatter
    RSpec::Core::Formatters.register(self, :dump_summary)

    def dump_summary(notification, timings)
      output_slowest_examples(timings) if timings.present?

      totals_by_id, totals_by_origin = aggregate_js_deprecations(notification.examples)

      if totals_by_id.present?
        report_path = write_js_deprecation_report(notification.examples)
        output_js_deprecations(totals_by_id, totals_by_origin, report_path)
      end

      super(notification)
    end

    private

    def output_slowest_examples(timings)
      output.puts "\nTop #{timings.size} Slowest examples:"
      timings.each do |(full_description, source_location, duration)|
        output.puts "  #{full_description}"
        output.puts "    #{RSpec::Core::Formatters::ConsoleCodes.wrap(duration.to_s + "ms", :bold)} #{source_location}"
      end
    end

    def aggregate_js_deprecations(examples)
      totals_by_id = Hash.new(0)
      totals_by_origin = Hash.new { |h, k| h[k] = Hash.new(0) }

      examples.each do |example|
        origin = extract_origin_from_example(example) || "unknown"

        example.metadata[:js_deprecations]&.each do |id, count|
          totals_by_id[id] += count
          totals_by_origin[origin][id] += count
        end
      end

      [totals_by_id, totals_by_origin]
    end

    def output_js_deprecations(totals_by_id, totals_by_origin, report_path = nil)
      output.puts "\n[Deprecation Counter] Test run completed with deprecations:\n\n"

      deprecations_table = generate_deprecations_table(totals_by_id)
      output.puts deprecations_table

      origin_table = nil
      if totals_by_origin.any?
        origin_table = generate_deprecations_by_origin_table(totals_by_origin)
        output.puts "\nDeprecations by spec origin:\n\n"
        output.puts origin_table
      end

      output.puts "\nDetailed report: #{report_path}\n" if report_path

      write_github_summary(deprecations_table, origin_table, report_path)
    end

    # Label identifying which CI run group produced a report, so the artifacts of
    # a single workflow run stay distinguishable.
    def js_deprecation_report_group
      ENV["DEPRECATION_REPORT_GROUP"].presence&.gsub(/[^\w.-]+/, "-") || "system"
    end

    # Pairs each collected JS deprecation with the spec that triggered it and,
    # via the frontend sourcemaps, the original call site it came from.
    def write_js_deprecation_report(examples)
      entries =
        examples.flat_map do |example|
          details = example.metadata[:js_deprecation_details]
          next [] if details.blank?

          details.map do |detail|
            {
              id: detail["id"],
              count: 1,
              origin: extract_origin_from_example(example) || "unknown",
              stack: detail["stack"],
              test: {
                module: nil,
                name: example.full_description,
                file: example.metadata[:rerun_file_path],
                declarationLine: example.location[/:(\d+)\z/, 1]&.to_i,
                callSiteLine: nil,
                callSiteCode: nil,
              },
            }
          end
        end

      return nil if entries.empty?

      group = js_deprecation_report_group
      dir =
        ENV["DEPRECATION_REPORT_DIR"].presence || Rails.root.join("tmp/deprecation-reports").to_s
      FileUtils.mkdir_p(dir)
      report_path = File.join(dir, "#{group}-#{Process.pid}.json")

      cli = Rails.root.join("frontend/discourse/lib/deprecation-report-cli.js").to_s
      IO.popen(["node", cli, group, report_path], "w") { |io| io.write(entries.to_json) }

      return nil unless $?.success?

      Pathname.new(report_path).relative_path_from(Rails.root).to_s
    rescue StandardError => e
      output.puts "\n[Deprecation Counter] Failed to build detailed report: #{e.message}\n"
      nil
    end

    def generate_deprecations_table(totals_by_id)
      max_id_length = totals_by_id.keys.map(&:length).max

      headers = ["id".ljust(max_id_length), "count".rjust(5)]
      rows = totals_by_id.map { |id, count| [id.ljust(max_id_length), count.to_s.rjust(5)] }

      build_markdown_table(headers, rows)
    end

    def generate_deprecations_by_origin_table(totals_by_origin)
      all_ids = totals_by_origin.values.flat_map(&:keys).uniq
      max_id_length = all_ids.map(&:length).max
      origins = totals_by_origin.keys.sort
      max_origin_length = [origins.map(&:length).max, 6].max

      headers = ["origin".ljust(max_origin_length), "id".ljust(max_id_length), "count".rjust(5)]
      rows = []

      origins.each do |origin|
        origin_deprecations = totals_by_origin[origin]
        sorted_ids = origin_deprecations.keys.sort

        sorted_ids.each do |id|
          count = origin_deprecations[id]
          rows += [[origin.ljust(max_origin_length), id.ljust(max_id_length), count.to_s.rjust(5)]]
        end
      end

      build_markdown_table(headers, rows)
    end

    def build_markdown_table(headers, rows)
      table = "| #{headers.join(" | ")} |\n"
      table += "| #{headers.map { |h| "-" * h.length }.join(" | ")} |\n"
      rows.each { |row| table += "| #{row.join(" | ")} |\n" }
      table
    end

    def write_github_summary(deprecations_table, origin_table, report_path = nil)
      return unless ENV["GITHUB_ACTIONS"] && ENV["GITHUB_STEP_SUMMARY"]

      summary = "### ⚠️ JS Deprecations\n\nTest run completed with deprecations:\n\n"
      summary += deprecations_table
      summary += "\n\nDeprecations by spec origin:\n\n#{origin_table}" if origin_table
      if report_path
        summary += "\n\nPer-deprecation call sites are in the `deprecation-reports` artifact."
      end
      summary += "\n\n"

      # Appended, so a job running several suites keeps every table.
      File.write(ENV["GITHUB_STEP_SUMMARY"], summary, mode: "a")
    end

    def extract_origin_from_example(example)
      example_file_path = example.metadata[:rerun_file_path]
      return nil unless example_file_path

      expanded_example_file_path = Pathname.new(example_file_path).expand_path
      return nil unless expanded_example_file_path.to_s.start_with?(Rails.root.to_s)

      extension_match = example_file_path.match(%r{/(plugins|themes)/([^/]+)/})
      if extension_match
        _type_dir, extension_name = extension_match.captures
        extension_name
      else
        "core"
      end
    end
  end
end
