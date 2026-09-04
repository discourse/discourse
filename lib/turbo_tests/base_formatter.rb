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
        summary = write_js_deprecation_report(notification.examples, totals_by_id, totals_by_origin)
        output.puts "\n#{summary}\n" if summary
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

      group = js_deprecation_report_group
      dir =
        ENV["DEPRECATION_REPORT_DIR"].presence || Rails.root.join("tmp/deprecation-reports").to_s
      FileUtils.mkdir_p(dir)
      report_path = File.join(dir, "#{group}-#{Process.pid}.json")

      payload = { entries:, totals: totals_by_id, totalsByOrigin: totals_by_origin }
      cli = Rails.root.join("frontend/discourse/lib/deprecation-report-cli.js").to_s
      summary =
        IO.popen(["node", cli, "build", report_path, group], "r+") do |io|
          io.write(payload.to_json)
          io.close_write
          io.read
        end

      return nil unless $?.success?

      summary
    rescue StandardError => e
      output.puts "\n[Deprecation Counter] Failed to build detailed report: #{e.message}\n"
      nil
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
