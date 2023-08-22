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

      super(notification)
    end
  end
end
