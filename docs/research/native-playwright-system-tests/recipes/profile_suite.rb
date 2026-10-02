# frozen_string_literal: true
require "stackprof"
require "json"
require "fileutils"
require "playwright"

module NativeResearchProtocol
  METRICS = Hash.new { |values, name| values[name] = { count: 0, seconds: 0.0 } }
  LOCK = Mutex.new

  def send_message_to_server_result(*arguments, **options)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    super
  ensure
    seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    name = "#{object.class.name}:#{arguments[-2]}"
    LOCK.synchronize do
      METRICS[name][:count] += 1
      METRICS[name][:seconds] += seconds
    end
  end
end

Playwright::Channel.prepend(NativeResearchProtocol)
StackProf.start(mode: ENV.fetch("NATIVE_PROFILE_MODE", "wall").to_sym, interval: 1000, raw: true)
at_exit do
  StackProf.stop
  result = StackProf.results
  directory = ENV.fetch("NATIVE_PROFILE_DIRECTORY", "tmp/native-playwright-research/profile")
  FileUtils.mkdir_p(directory)
  stem = File.join(directory, "worker-#{ENV.fetch("TEST_ENV_NUMBER", "1")}-pid-#{Process.pid}")
  File.binwrite("#{stem}.dump", Marshal.dump(result)) if result
  File.write("#{stem}-protocol.json", JSON.pretty_generate(NativeResearchProtocol::METRICS))
  puts "Native research profile saved: #{stem}"
end
