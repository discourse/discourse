# frozen_string_literal: true
class NativeBrowserClock
  def initialize(driver)
    @driver = driver
    @scripts = []
  end

  def install(time: nil)
    install_if_needed
    milliseconds =
      case time
      when nil
        Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
      when Numeric
        time
      when String
        (Time.parse(time).to_f * 1000).round
      else
        (time.to_time.to_f * 1000).round
      end
    record("install", milliseconds)
    @driver.evaluate_in_frame_contexts("globalThis.__pwClock.controller.install(#{milliseconds})")
  end

  def resume
    install_if_needed
    record("resume")
    @driver.evaluate_in_frame_contexts("globalThis.__pwClock.controller.resume()")
  end

  def reset
    return if @scripts.empty?
    @scripts.each do |identifier|
      @driver.command("Page.removeScriptToEvaluateOnNewDocument", { identifier: identifier })
    end
    @scripts.clear
    @driver.evaluate_in_frame_contexts("globalThis.__pwClock?.controller.uninstall()")
  end

  private

  def record(method, *arguments)
    recorded_at = Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
    script = "globalThis.__pwClock.controller.log(...#{[method, recorded_at, *arguments].to_json})"
    @scripts << @driver.command("Page.addScriptToEvaluateOnNewDocument", { source: script }).fetch(
      "identifier",
    )
  end

  def install_if_needed
    return unless @scripts.empty?
    script = <<~JS
      (() => {
        const module = {};
        #{File.read(File.join(__dir__, "playwright-clock.js"))}
        if (!globalThis.__pwClock) globalThis.__pwClock = (module.exports.inject())(globalThis, "chromium");
      })();
    JS
    @scripts << @driver.command("Page.addScriptToEvaluateOnNewDocument", { source: script }).fetch(
      "identifier",
    )
    @driver.evaluate_in_frame_contexts(script)
  end
end
