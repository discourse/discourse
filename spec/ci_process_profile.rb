# frozen_string_literal: true

require "etc"
require "json"

class CiProcessProfile
  def initialize(proc_root: "/proc", clock_ticks: Etc.sysconf(Etc::SC_CLK_TCK))
    @proc_root = proc_root
    @clock_ticks = clock_ticks
    @cpu_ticks = { ruby: 0, chromium: 0, node: 0, postgres: 0, other: 0 }
    @chromium_ticks = { browser: 0, renderer: 0, gpu: 0, utility: 0, zygote: 0, other: 0 }
    @last_ticks = {}
    @active = {}
    @counts = {
      samples: 0,
      matched_process_observations: 0,
      baseline_processes: 0,
      late_baseline_processes: 0,
      new_processes: 0,
      missed_process_observations: 0,
      vanished_processes: 0,
      errors: 0,
      classification_read_errors: 0,
    }
    @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @initial_sample = true
    @available = false
    begin
      raise ArgumentError if !clock_ticks.is_a?(Integer) || clock_ticks <= 0
      @cgroup = File.binread(File.join(proc_root, "self/cgroup"))
      raise ArgumentError if @cgroup.empty?
      uptime = Float(File.read(File.join(proc_root, "uptime")).split.first)
      raise ArgumentError if !uptime.finite? || uptime < 0
      @baseline_ticks = (uptime * clock_ticks).floor
      @available = true
    rescue SystemCallError, ArgumentError, TypeError
      @counts[:errors] += 1
    end
  end

  def sample
    @counts[:samples] += 1
    return if !@available
    begin
      pids = Dir.children(@proc_root).grep(/\A[1-9][0-9]*\z/).to_h { |pid| [pid, true] }
    rescue SystemCallError
      @counts[:errors] += 1
      return
    end

    identities = {}
    pids.each_key do |pid|
      directory = File.join(@proc_root, pid)
      before = parse_stat(File.binread(File.join(directory, "stat")))
      raise ArgumentError if before[:pid] != pid
      identities[pid] = [pid, before[:start_ticks]]
      next if File.binread(File.join(directory, "cgroup")) != @cgroup
      process_bucket = bucket(before[:comm])
      if process_bucket == :other
        begin
          executable = File.basename(File.readlink(File.join(directory, "exe")))
          process_bucket = :ruby if bucket(executable) == :ruby
        rescue SystemCallError
          @counts[:classification_read_errors] += 1
        end
      end
      chromium_type = :other
      if process_bucket == :chromium && before[:comm] != "chrome_crashpad"
        begin
          chromium_type = chromium_bucket(File.binread(File.join(directory, "cmdline")))
        rescue SystemCallError
          @counts[:classification_read_errors] += 1
        end
      end
      current = parse_stat(File.binread(File.join(directory, "stat")))
      if current[:pid] != pid || current[:start_ticks] != before[:start_ticks] ||
           current[:comm] != before[:comm]
        @counts[:missed_process_observations] += 1
        next
      end

      identity = [pid, current[:start_ticks]]
      @counts[:matched_process_observations] += 1
      previous_ticks = @last_ticks[identity]
      delta_ticks = 0
      if previous_ticks
        if current[:cpu_ticks] >= previous_ticks
          delta_ticks = current[:cpu_ticks] - previous_ticks
        else
          @counts[:errors] += 1
        end
      elsif @initial_sample || current[:start_ticks] <= @baseline_ticks
        @counts[:baseline_processes] += 1
        @counts[:late_baseline_processes] += 1 if !@initial_sample
      else
        @counts[:new_processes] += 1
        delta_ticks = current[:cpu_ticks]
      end
      @cpu_ticks[process_bucket] += delta_ticks
      @chromium_ticks[chromium_type] += delta_ticks if process_bucket == :chromium
      @last_ticks[identity] = [previous_ticks || 0, current[:cpu_ticks]].max
      @active[identity] = pid
    rescue Errno::ENOENT, Errno::ESRCH
      @counts[:missed_process_observations] += 1
    rescue SystemCallError, ArgumentError
      @counts[:errors] += 1
    end

    @active.delete_if do |identity, pid|
      vanished = !pids.key?(pid) || (identities.key?(pid) && identities[pid] != identity)
      @counts[:vanished_processes] += 1 if vanished
      vanished
    end
    @initial_sample = false
  end

  def report
    {
      available: @available,
      sample_interval_seconds: 1,
      elapsed_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at,
      cpu_seconds:
        @cpu_ticks.transform_values { |ticks| @available ? ticks.fdiv(@clock_ticks) : nil },
      chromium_cpu_seconds:
        @chromium_ticks.transform_values { |ticks| @available ? ticks.fdiv(@clock_ticks) : nil },
      **@counts,
      short_lived_processes_may_be_unobserved: true,
    }
  end

  private

  def parse_stat(text)
    match = /\A([1-9][0-9]*) \((.*)\) (.*)\z/m.match(text)
    raise ArgumentError if !match
    fields = match[3].split
    raise ArgumentError if fields.length < 20
    user_ticks, system_ticks, start_ticks = [11, 12, 19].map { |index| Integer(fields[index], 10) }
    raise ArgumentError if [user_ticks, system_ticks, start_ticks].any?(&:negative?)
    {
      pid: match[1],
      comm: match[2],
      cpu_ticks: user_ticks + system_ticks,
      start_ticks: start_ticks,
    }
  end

  def bucket(comm)
    case comm
    when "ruby", "ruby3.1", "ruby3.2", "ruby3.3", "ruby3.4", "ruby3.5", "ruby4.0"
      :ruby
    when "chrome", "chromium", "chromium-browse", "chrome-headless", "chrome_crashpad"
      :chromium
    when "node", "nodejs"
      :node
    when "postgres", "postmaster"
      :postgres
    else
      :other
    end
  end

  def chromium_bucket(cmdline)
    arguments = cmdline.split("\0")
    return :other if arguments.empty?
    arguments = arguments.first.split(/\s+/) if arguments.length == 1
    types = arguments.drop(1).select { |argument| argument.start_with?("--type=") }
    return :other if types.length != 1
    {
      "--type=renderer" => :renderer,
      "--type=gpu-process" => :gpu,
      "--type=utility" => :utility,
      "--type=zygote" => :zygote,
    }.fetch(types.first, :other)
  end
end

if $PROGRAM_NAME == __FILE__
  stopped = false
  Signal.trap("TERM") { stopped = true }
  Signal.trap("INT") { stopped = true }
  sampler = CiProcessProfile.new
  sampler.sample
  until stopped
    sleep 1
    sampler.sample unless stopped
  end
  sampler.sample
  puts "CI_PROCESS_CPU #{JSON.generate(sampler.report)}"
end
