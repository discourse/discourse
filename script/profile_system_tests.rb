# frozen_string_literal: true

require "fileutils"
require "json"

module SystemTestNavigationProfile
  def visit(...)
    profile = RSpec.current_example&.metadata&.[](:system_wall_profile)
    started_at_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) if profile
    super
  ensure
    if profile && started_at_seconds
      location = caller_locations(1, 20).find { |caller| caller.path.match?(%r{(?:\A|/)spec/}) }
      profile[:visits] << {
        started_at_seconds:,
        elapsed_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at_seconds,
        source: location&.path,
        line: location&.lineno,
      }
    end
  end
end

class SystemTestWallFormatter
  RSpec::Core::Formatters.register(self, :example_started, :example_finished, :close)

  def initialize(_output)
    @started_at_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @examples = []
  end

  def example_started(notification)
    example = notification.example
    example.metadata[:system_wall_profile] = {
      id: example.id,
      started_at_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC),
      visits: [],
    }
  end

  def example_finished(notification)
    example = notification.example
    profile = example.metadata.fetch(:system_wall_profile)
    profile[:elapsed_seconds] = Process.clock_gettime(Process::CLOCK_MONOTONIC) -
      profile[:started_at_seconds]
    profile[:status] = example.execution_result.status
    @examples << profile
  end

  def close(_notification)
    directory = ENV.fetch("SYSTEM_TEST_PROFILE_DIR", "tmp/capybara")
    FileUtils.mkdir_p(directory)
    worker = ENV.fetch("TEST_ENV_NUMBER", "0")
    File.write(
      File.join(directory, "system-wall-profile-#{worker}-#{Process.pid}.json"),
      JSON.generate(
        worker:,
        started_at_seconds: @started_at_seconds,
        elapsed_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at_seconds,
        process_cpu_seconds: Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID),
        examples: @examples,
      ),
    )
  end
end

RSpec.configure do |config|
  config.add_formatter(SystemTestWallFormatter)
  config.before(:suite) { Capybara::Session.prepend(SystemTestNavigationProfile) }
end
