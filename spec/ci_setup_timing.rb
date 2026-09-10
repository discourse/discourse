# frozen_string_literal: true

if ENV["DISCOURSE_CI_SETUP_TIMING"] == "1"
  require "json"

  timing_mutex = Mutex.new
  timings = {}
  registrations = {
    test_setup: [TestSetup.singleton_class, :test_setup],
    site_setting_refresh: [SiteSetting.singleton_class, :refresh!],
    system_setup: [SystemHelpers, :setup_system_test],
    browser_reset: [Capybara::Playwright::Driver, :reset!],
  }

  registrations.each do |metric, (target, method_name)|
    timings[metric] = { calls: 0, seconds: 0.0 }
    target.prepend(
      Module.new do
        define_method(method_name) do |*args, **kwargs, &block|
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          begin
            super(*args, **kwargs, &block)
          ensure
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
            timing_mutex.synchronize do
              timings[metric][:calls] += 1
              timings[metric][:seconds] += elapsed
            end
          end
        end
      end,
    )
  end

  at_exit do
    worker_number = ENV["TEST_ENV_NUMBER"].to_s
    worker =
      if worker_number.empty?
        "multisite"
      elsif worker_number.match?(/\A[1-9][0-9]{0,3}\z/)
        worker_number
      else
        "unknown"
      end

    process_times = Process.times
    summary =
      timing_mutex.synchronize do
        JSON.generate(
          worker: worker,
          timings: timings,
          process_user_seconds: process_times.utime,
          process_system_seconds: process_times.stime,
          gc_seconds: GC.total_time / 1_000_000_000.0,
          gc_count: GC.stat(:count),
        )
      end
    puts "CI_SETUP_TIMING #{summary}"
  end
end
