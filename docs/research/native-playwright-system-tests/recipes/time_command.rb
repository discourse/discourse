# frozen_string_literal: true
require "json"

initial_cpu = Process.times
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
child_pid = Process.spawn(*ARGV)
_, status = Process.wait2(child_pid)
finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
cpu = Process.times
result = {
  command: ARGV,
  elapsed_seconds: finished - started,
  exit_code: status.exitstatus,
  signal: status.termsig,
  child_cpu_user_seconds: cpu.cutime - initial_cpu.cutime,
  child_cpu_system_seconds: cpu.cstime - initial_cpu.cstime,
  memory: "not collected by this timer",
}
File.write("/tmp/native-pilot-timing.json", JSON.pretty_generate(result))
puts "NATIVE_PILOT_TIMING=#{JSON.generate(result)}"
exit(status.exitstatus || 1)
