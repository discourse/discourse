# frozen_string_literal: true
RSpec.describe NativeSystemDriver, type: :system do
  describe "#invalid_element_errors" do
    it "classifies a detached click target as a stale element" do
      visit "data:text/html;charset=utf-8,<button id='target'>Target</button>"
      target = page.driver.find_css("#target").first
      page.execute_script("document.querySelector('#target').remove()")

      expect { target.click }.to raise_error(NativeSystemDriver::StaleElement)
      expect { target.native.scroll_into_view_if_needed }.to raise_error(
        NativeSystemDriver::StaleElement,
      )
    end
  end
end

RSpec.describe NativeSystemDriver, type: :system do
  describe "#reset!" do
    it "leaves a page with an unload confirmation" do
      visit "data:text/html;charset=utf-8,<button id='activate'>Activate</button>"
      find("#activate").click
      page.execute_script(<<~JS)
        window.addEventListener('beforeunload', event => {
          event.preventDefault();
          event.returnValue = '';
        });
      JS

      driver = page.driver
      reset = Thread.new { driver.reset! }
      completed = reset.join(5)
      unless completed
        driver.command("Page.handleJavaScriptDialog", { accept: true })
        reset.join(5)
      end

      expect(completed).not_to eq(nil)
      expect(driver.current_url).to eq("about:blank")
    ensure
      reset&.join(5)
    end
  end
end

RSpec.describe NativeSystemDriver, type: :system do
  it "round-trips repeated browser script evaluations" do
    visit "data:text/html;charset=utf-8,<title>driver-benchmark</title>"

    warmup_count = 100
    warmup_results = Array.new(warmup_count) { page.evaluate_script("1 + 1") }
    expect(warmup_results).to eq(Array.new(warmup_count, 2))

    operation_count = 500
    sample_count = 5
    samples =
      Array.new(sample_count) do
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        results = Array.new(operation_count) { page.evaluate_script("1 + 1") }
        elapsed_milliseconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
        expect(results).to eq(Array.new(operation_count, 2))
        elapsed_milliseconds
      end

    bridge = { "ruby" => "ruby", "rust" => "rust" }.fetch(ENV["NATIVE_CDP_BRIDGE_LABEL"], "unknown")
    median_elapsed_milliseconds = samples.sort.fetch(sample_count / 2)

    warn(
      "NATIVE_CDP_EVALUATE_ROUND_TRIPS bridge=#{bridge} warmup_operations=#{warmup_count} " \
        "operations_per_sample=#{operation_count} sample_count=#{sample_count} " \
        "samples_ms=#{samples.map { |sample| format("%.3f", sample) }.join(",")}" \
        " median_ms=#{format("%.3f", median_elapsed_milliseconds)}",
    )
  end
end

RSpec.describe NativeSystemDriver, type: :system do
  it "round-trips repeated browser reset commands" do
    visit "data:text/html;charset=utf-8,<title>storage-clear-benchmark</title>"
    driver = page.driver

    sample_count = 3
    storage_clear_samples =
      Array.new(sample_count) do
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = driver.command("Storage.clearDataForOrigin", { origin: "*", storageTypes: "all" })
        elapsed_milliseconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
        expect(result).to eq({})
        elapsed_milliseconds
      end
    target_listing_samples =
      Array.new(sample_count) do
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = driver.command("Target.getTargets", {}, browser: true)
        elapsed_milliseconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
        expect(result.fetch("targetInfos")).to be_an(Array)
        elapsed_milliseconds
      end

    bridge = { "ruby" => "ruby", "rust" => "rust" }.fetch(ENV["NATIVE_CDP_BRIDGE_LABEL"], "unknown")
    {
      "Storage.clearDataForOrigin" => storage_clear_samples,
      "Target.getTargets" => target_listing_samples,
    }.each do |method, samples|
      warn(
        "NATIVE_CDP_RESET_COMMAND bridge=#{bridge} method=#{method} sample_count=#{sample_count} " \
          "samples_ms=#{samples.map { |sample| format("%.3f", sample) }.join(",")}",
      )
    end
  end
end

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
