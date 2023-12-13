# frozen_string_literal: true

RSpec::Support.require_rspec_core "formatters/base_text_formatter"
RSpec::Support.require_rspec_core "formatters/console_codes"

module TurboTests
  class BaseFormatter < RSpec::Core::Formatters::BaseTextFormatter
    RSpec::Core::Formatters.register(self, :dump_summary)

    def dump_summary(notification, timings)
      if timings.present?
        output.puts "\nTop #{timings.size} Slowest examples:"

        timings.each do |(full_description, source_location, duration)|
          output.puts "  #{full_description}"
          output.puts "    #{RSpec::Core::Formatters::ConsoleCodes.wrap(duration.to_s + "ms", :bold)} #{source_location}"
        end
      end

      js_deprecation_totals = {}
      notification.examples.each do |example|
        example.metadata[:js_deprecations]&.each do |id, count|
          js_deprecation_totals[id] ||= 0
          js_deprecation_totals[id] += count
        end
      end

      if js_deprecation_totals.present?
        max_id_length = js_deprecation_totals.keys.map(&:length).max
        output.puts "\n[Deprecation Counter] Test run completed with deprecations:\n\n"

        table = ""
        table += "| #{"id".ljust(max_id_length)} | count |\n"
        table += "| #{"-" * max_id_length} | ----- |\n"
        js_deprecation_totals.each do |id, count|
          table += "| #{id.ljust(max_id_length)} | #{count.to_s.ljust(5)} |\n"
        end

        output.puts table

        if ENV["GITHUB_ACTIONS"] && ENV["GITHUB_STEP_SUMMARY"]
          job_summary = "### ⚠️ JS Deprecations\n\nTest run completed with deprecations:\n\n"
          job_summary += table
          job_summary += "\n\n"
          File.write(ENV["GITHUB_STEP_SUMMARY"], job_summary)
        end
      end

      super(notification)
    end
  end
end
