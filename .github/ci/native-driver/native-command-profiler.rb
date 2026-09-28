# frozen_string_literal: true

require_relative "native-lifecycle-waits"

module NativeSystemDriverCommandProfiler
  PROFILE_THREAD_KEY = :native_system_driver_command_profile
  PROFILED_ABOUT_PAGE_EXAMPLES = {
    "displays only the 6 most recently seen admins when there are more than 6 admins" => "warmup",
    "allows expanding and collapsing the list of admins" => "measure",
  }.freeze

  def command(method, params = {}, browser: false, session: nil)
    profile = Thread.current.thread_variable_get(PROFILE_THREAD_KEY)
    return super unless profile

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    phase = profile[:phase] || "example"
    super
  ensure
    if profile && started_at
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      safe_method =
        method.to_s.match?(/\A[A-Za-z][A-Za-z0-9]*\.[A-Za-z][A-Za-z0-9]*\z/) ? method.to_s : "other"
      profile[:mutex].synchronize { profile[:durations][phase][safe_method] << elapsed }
    end
  end

  def start
    with_profile_phase("start") { super }
  end

  def visit(url)
    profile = Thread.current.thread_variable_get(PROFILE_THREAD_KEY)
    phase = profile && profile[:phase] == "reset" ? "reset_visit" : "visit"
    with_profile_phase(phase) { super }
  end

  def reset!
    with_profile_phase("reset") { super }
  end

  private

  def with_profile_phase(phase)
    profile = Thread.current.thread_variable_get(PROFILE_THREAD_KEY)
    return yield unless profile

    previous_phase = profile[:phase]
    profile[:phase] = phase
    yield
  ensure
    profile[:phase] = previous_phase if profile
  end
end

NativeSystemDriver.prepend(NativeSystemDriverCommandProfiler)

RSpec.configure do |config|
  config.around(:example) do |example|
    profiled_example =
      if ENV["NATIVE_CDP_COMMAND_PROFILE"] == "1" &&
           example.metadata[:file_path].to_s.end_with?("spec/system/about_page_spec.rb")
        NativeSystemDriverCommandProfiler::PROFILED_ABOUT_PAGE_EXAMPLES[
          example.metadata[:description]
        ]
      end

    unless profiled_example
      example.run
      next
    end

    profile = {
      durations:
        Hash.new do |phases, phase|
          phases[phase] = Hash.new { |commands, method| commands[method] = [] }
        end,
      mutex: Mutex.new,
    }
    previous_profile =
      Thread.current.thread_variable_get(NativeSystemDriverCommandProfiler::PROFILE_THREAD_KEY)
    Thread.current.thread_variable_set(
      NativeSystemDriverCommandProfiler::PROFILE_THREAD_KEY,
      profile,
    )

    begin
      example.run
    ensure
      Thread.current.thread_variable_set(
        NativeSystemDriverCommandProfiler::PROFILE_THREAD_KEY,
        previous_profile,
      )
      bridge = { "ruby" => "ruby", "rust" => "rust" }.fetch(
        ENV["NATIVE_CDP_BRIDGE_LABEL"],
        "unknown",
      )
      command_profile =
        profile[:durations].sort.to_h do |phase, commands|
          [
            phase,
            commands.sort.to_h do |method, durations|
              sorted_durations = durations.sort
              p50_index = (sorted_durations.length * 0.5).ceil - 1
              p95_index = (sorted_durations.length * 0.95).ceil - 1
              [
                method,
                {
                  count: durations.length,
                  total_ms: (durations.sum * 1000).round(3),
                  p50_ms: (sorted_durations.fetch(p50_index) * 1000).round(3),
                  p95_ms: (sorted_durations.fetch(p95_index) * 1000).round(3),
                  max_ms: (sorted_durations.last * 1000).round(3),
                },
              ]
            end,
          ]
        end
      warn(
        "NATIVE_CDP_COMMAND_PROFILE bridge=#{bridge} example=#{profiled_example} " \
          "#{JSON.generate(command_profile)}",
      )
    end
  end
end
