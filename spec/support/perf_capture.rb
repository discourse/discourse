# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    if Discourse::PerformanceFormatter.enabled?
      MethodProfiler.ensure_discourse_instrumentation!
      MethodProfiler.itemize_enabled = true
    end
  end

  config.around(:each) do |example|
    unless Discourse::PerformanceFormatter.enabled?
      example.run
      next
    end

    test_summary = nil
    request_groups =
      Discourse::PerformanceFormatter::Capture.collect_requests do
        test_summary = Discourse::PerformanceFormatter::Capture.measure { example.run }
      end

    example.metadata[:perf] = Discourse::PerformanceFormatter.assemble(test_summary, request_groups)
  end
end
