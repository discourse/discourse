# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    if RspecPerformanceFormatter.enabled?
      MethodProfiler.ensure_discourse_instrumentation!
      MethodProfiler.itemize_enabled = true
    end
  end

  config.around(:each) do |example|
    unless RspecPerformanceFormatter.enabled?
      example.run
      next
    end

    test_summary = nil
    request_groups =
      RspecPerformanceFormatter.collect_requests do
        test_summary = RspecPerformanceFormatter.measure { example.run }
      end

    example.metadata[:perf] = RspecPerformanceFormatter.assemble(test_summary, request_groups)
  end
end
