# frozen_string_literal: true
require "open3"

RSpec::Support.require_rspec_core "formatters/base_text_formatter"
RSpec::Support.require_rspec_core "formatters/console_codes"

module TurboTests
  class BaseFormatter < RSpec::Core::Formatters::BaseTextFormatter
    RSpec::Core::Formatters.register(self, :dump_summary)

    def dump_summary(notification, timings)
      output_slowest_examples(timings) if timings.present?

      totals_by_id, totals_by_origin = aggregate_js_deprecations(notification.examples)

      if totals_by_id.present?
        summary = write_js_deprecation_report(notification.examples, totals_by_id, totals_by_origin)
        summary ||= fallback_js_deprecation_summary(totals_by_id, totals_by_origin)
        output.puts "\n#{summary}\n"
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

    # Label identifying which CI run group produced a report, so the artifacts of
    # a single workflow run stay distinguishable.
    def js_deprecation_report_group
      ENV["DEPRECATION_REPORT_GROUP"].presence&.gsub(/[^\w.-]+/, "-") || "system"
    end

    # Pairs each collected JS deprecation with the spec that triggered it and,
    # via the frontend sourcemaps, the original call site it came from.
    def write_js_deprecation_report(examples, totals_by_id, totals_by_origin)
      entries =
        examples.flat_map do |example|
          details = example.metadata[:js_deprecation_details]
          next [] if details.blank?

          location = example.location_rerun_argument.presence || example.location
          test_file, _, test_line = location.rpartition(":")

          details.map do |detail|
            {
              id: detail["id"],
              count: 1,
              origin: extract_origin_from_example(example) || "unknown",
              stack: detail["stack"],
              reportAtCallSite: detail["reportAtCallSite"],
              test: {
                module: nil,
                name: example.full_description,
                file: test_file,
                declarationLine: test_line.to_i,
                callSiteLine: nil,
                callSiteCode: nil,
              },
            }
          end
        end

      group = js_deprecation_report_group
      dir =
        ENV["DEPRECATION_REPORT_DIR"].presence || Rails.root.join("tmp/deprecation-reports").to_s
      FileUtils.mkdir_p(dir)
      report_path = File.join(dir, "#{group}-#{Process.pid}.json")

      payload = { entries:, totals: totals_by_id, totalsByOrigin: totals_by_origin }
      cli = Rails.root.join("frontend/discourse/lib/deprecation-report-cli.js").to_s
      summary, stderr, status =
        Open3.capture3("node", cli, "build", report_path, group, stdin_data: payload.to_json)

      unless status.success?
        reason = status.signaled? ? "signal #{status.termsig}" : "exit status #{status.exitstatus}"
        output.puts "\n[Deprecation Counter] Failed to build detailed report (#{reason})."
        output.puts stderr if stderr.present?
        return nil
      end

      output.puts stderr if stderr.present?
      summary
    rescue StandardError => e
      output.puts "\n[Deprecation Counter] Failed to build detailed report: #{e.message}\n"
      nil
    end

    def fallback_js_deprecation_summary(totals_by_id, totals_by_origin)
      summary = +"[Deprecation Counter] Test run completed with deprecations:\n\n"
      summary << "| id | count |\n| --- | --- |\n"
      totals_by_id.sort.each { |id, count| summary << "| #{id} | #{count} |\n" }

      if totals_by_origin.any?
        summary << "\nDeprecations by spec origin:\n\n"
        summary << "| origin | id | count |\n| --- | --- | --- |\n"
        totals_by_origin.sort.each do |origin, counts|
          counts.sort.each { |id, count| summary << "| #{origin} | #{id} | #{count} |\n" }
        end
      end

      summary
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
