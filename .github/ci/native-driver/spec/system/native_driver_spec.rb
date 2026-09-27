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

module NativeSystemDriverCommandProfiler
  PROFILE_THREAD_KEY = :native_system_driver_command_profile

  def command(method, params = {}, browser: false, session: nil)
    profile = Thread.current.thread_variable_get(PROFILE_THREAD_KEY)
    return super unless profile

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    super
  ensure
    if profile && started_at
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      safe_method =
        method.to_s.match?(/\A[A-Za-z][A-Za-z0-9]*\.[A-Za-z][A-Za-z0-9]*\z/) ? method.to_s : "other"
      profile[:mutex].synchronize { profile[:durations][safe_method] << elapsed }
    end
  end
end

NativeSystemDriver.prepend(NativeSystemDriverCommandProfiler)

RSpec.configure do |config|
  config.around(:example) do |example|
    about_page_example =
      ENV["NATIVE_CDP_COMMAND_PROFILE"] == "1" &&
        example.metadata[:file_path].to_s.end_with?("spec/system/about_page_spec.rb") &&
        example.metadata[:description] == "allows expanding and collapsing the list of admins"

    unless about_page_example
      example.run
      next
    end

    profile = { durations: Hash.new { |commands, method| commands[method] = [] }, mutex: Mutex.new }
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
        profile[:durations].sort.to_h do |method, durations|
          [
            method,
            {
              count: durations.length,
              total_ms: (durations.sum * 1000).round(3),
              max_ms: (durations.max * 1000).round(3),
            },
          ]
        end
      warn("NATIVE_CDP_COMMAND_PROFILE bridge=#{bridge} #{JSON.generate(command_profile)}")
    end
  end
end
