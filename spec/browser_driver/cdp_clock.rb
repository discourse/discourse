# frozen_string_literal: true

class NativeBrowserClock
  CLOCK = File.read(File.join(__dir__, "browser-clock.js")).freeze
  private_constant :CLOCK

  def initialize(driver)
    @driver = driver
  end

  def install(time: nil)
    now = Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
    epoch =
      case time
      when nil
        now
      when Numeric
        time
      when String
        (Time.parse(time).to_f * 1000).round
      else
        (time.to_time.to_f * 1000).round
      end
    @offset = epoch - now
    source = "#{CLOCK}\nglobalThis.__discourseClock.setOffset(#{@offset});"
    @driver.add_init_script(script: source)
    @driver.evaluate_in_frame_contexts(source)
  end

  def fast_forward(milliseconds)
    install unless @offset
    @offset += milliseconds
    @driver.add_init_script(script: "globalThis.__discourseClock.setOffset(#{@offset});")
    @driver.evaluate_in_frame_contexts("globalThis.__discourseClock.fastForward(#{milliseconds});")
  end
end
