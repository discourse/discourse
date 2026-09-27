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
