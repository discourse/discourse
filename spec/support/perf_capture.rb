# frozen_string_literal: true

if ENV["DISCOURSE_RSPEC_PERFORMANCE_FORMATTER"] == "1"
  require_relative "rspec_performance_formatter"

  RSpec.configure do |config|
    config.before(:suite) { MethodProfiler.ensure_discourse_instrumentation! }

    config.around(:each) do |example|
      test_summary = nil
      request_groups =
        RspecPerformanceFormatter.collect_requests do
          test_summary = RspecPerformanceFormatter.measure { example.run }
        end

      example.metadata[:perf] = RspecPerformanceFormatter.assemble(test_summary, request_groups)
    end
  end
end
