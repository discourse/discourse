# frozen_string_literal: true

module Demon
end

# intelligent fork based demonizer
class Demon::Base
  HOSTNAME = Socket.gethostname

  def self.demons
    @demons
  end

  class << self
    # Set when pitchfork reforks under a supervisor process. Demons then watch
    # the supervisor instead of the service worker that started them, so they
    # outlive it until its successor has started their replacements (see
    # #start), and server-lifetime demons run under the service keeper.
    def handoff_supervisor_pid
      Demon::Base.instance_variable_get(:@handoff_supervisor_pid)
    end

    def handoff_supervisor_pid=(pid)
      Demon::Base.instance_variable_set(:@handoff_supervisor_pid, pid)
    end
  end

  if Rails.env.test?
    def self.set_demons(demons)
      @demons = demons
    end

    def self.reset_demons
      @demons = {}
    end

    def set_pid(pid)
      @pid = pid
    end
  end

  def self.start(count = 1, verbose: false, logger: nil)
    @demons ||= {}
    count.times { |i| (@demons["#{prefix}_#{i}"] ||= new(i, verbose:, logger:)).start }
  end

  def self.stop
    return unless @demons
    @demons.values.each { |demon| demon.stop }
  end

  def self.restart
    return unless @demons
    @demons.values.each { |demon| demon.restart }
  end

  def self.ensure_running
    @demons.values.each { |demon| demon.ensure_running }
  end

  def self.kill(signal)
    return unless @demons
    @demons.values.each { |demon| demon.kill(signal) }
  end

  attr_reader :pid, :parent_pid, :started, :index

  def initialize(index, rails_root: nil, parent_pid: nil, verbose: false, logger: nil)
    @index = index
    @pid = nil
    @parent_pid = parent_pid || Process.pid
    @started = false
    @rails_root = rails_root || Rails.root
    @verbose = verbose
    @logger = logger || Logger.new(STDERR)
  end

  def log(message, level: :info)
    @logger.public_send(level, message)
  end

  def pid_file
    "#{@rails_root}/tmp/pids/#{self.class.prefix}_#{@index}.pid"
  end

  def alive?(pid = nil)
    pid ||= @pid
    if pid
      Demon::Base.alive?(pid)
    else
      false
    end
  end

  def kill(signal)
    Process.kill(signal, @pid)
  end

  def stop_signal
    "HUP"
  end

  def stop_timeout
    10
  end

  def restart
    stop
    start
  end

  def stop
    @started = false

    if keeper_managed?
      ServiceKeeper.stop(keeper_name)
      @pid = nil
      return
    end

    if @pid
      Process.kill(stop_signal, @pid)

      wait_for_stop =
        lambda do
          timeout = stop_timeout

          while alive? && timeout > 0
            timeout -= (stop_timeout / 10.0)
            sleep(stop_timeout / 10.0)
            begin
              Process.waitpid(@pid, Process::WNOHANG)
            rescue StandardError
              -1
            end
          end

          begin
            Process.waitpid(@pid, Process::WNOHANG)
          rescue StandardError
            -1
          end
        end

      wait_for_stop.call

      if alive?
        log(
          "Process would not terminate cleanly, force quitting. pid: #{@pid} #{self.class}\n#{caller.join("\n")}",
          level: :warn,
        )

        Process.kill("KILL", @pid)
      end

      wait_for_stop.call

      @pid = nil
      @started = false
    end
  end

  def ensure_running
    return unless @started

    if keeper_managed?
      # The keeper restarts crashed services itself; this also respawns the
      # keeper if it has gone away.
      @pid = ServiceKeeper.ensure_running(keeper_name, server_lifetime_spec)
      return
    end

    if !@pid
      @started = false
      start
      return
    end

    dead =
      begin
        Process.waitpid(@pid, Process::WNOHANG)
      rescue StandardError
        -1
      end

    if dead
      log("Detected dead worker #{@pid}, restarting...")
      @pid = nil
      @started = false
      start
    end
  end

  def start
    return if @pid || @started

    existing = already_running? if !keeper_managed?

    if existing && Demon::Base.handoff_supervisor_pid
      # Left running by the previous service worker: start the replacement
      # first so there is no gap, then let the old one shut down gracefully.
      @started = true
      run
      stop_previous(existing)
      return
    elsif existing
      # should not happen ... so kill violently
      log("Attempting to kill pid #{existing}")
      Process.kill("TERM", existing)
    end

    @started = true
    run
  end

  # Processes that hold no Discourse heap and must survive service worker
  # rotation can return a spec (see ServiceKeeper.ensure_running); they then
  # run under the service keeper when reforking is enabled.
  def server_lifetime_spec
    nil
  end

  def keeper_managed?
    !!(Demon::Base.handoff_supervisor_pid && ServiceKeeper.enabled? && server_lifetime_spec)
  end

  def run
    if keeper_managed?
      @pid = ServiceKeeper.ensure_running(keeper_name, server_lifetime_spec)
      write_pid_file
      return
    end

    Discourse.before_fork if defined?(Discourse)

    @pid =
      fork do
        Process.setproctitle("discourse #{self.class.prefix}")
        monitor_parent
        establish_app
        after_fork
      end

    write_pid_file
  end

  def already_running?
    if File.exist? pid_file
      pid = File.read(pid_file).to_i
      return pid if Demon::Base.alive?(pid)
    end

    nil
  end

  def self.alive?(pid)
    Process.kill(0, pid)
    true
  rescue StandardError
    false
  end

  # Like .alive?, but a zombie counts as gone: the supervisor may exit before
  # its own parent reaps it.
  def self.running?(pid)
    return false if !alive?(pid)

    stat = File.read("/proc/#{pid}/stat")
    stat[stat.rindex(")") + 2] != "Z"
  rescue Errno::ENOENT
    false
  rescue SystemCallError
    true
  end

  private

  def keeper_name
    "#{self.class.prefix}_#{@index}"
  end

  # TERM rather than #stop_signal: the default HUP handler deletes the pid
  # file, which by now belongs to the replacement.
  def stop_previous(pid)
    log("Stopping previous #{self.class.prefix} pid #{pid} after starting #{@pid}")

    Thread.new do
      Process.kill("TERM", pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + stop_timeout
      while Demon::Base.alive?(pid) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        sleep 0.5
      end
      Process.kill("KILL", pid) if Demon::Base.alive?(pid)
    rescue Errno::ESRCH
    end
  end

  def verbose(msg)
    puts msg if @verbose
  end

  def write_pid_file
    verbose("writing pid file #{pid_file} for #{@pid}")
    FileUtils.mkdir_p(@rails_root + "tmp/pids")
    File.open(pid_file, "w") { |f| f.write(@pid) }
  end

  def delete_pid_file
    File.delete(pid_file)
  end

  def monitor_parent
    Thread.new do
      loop do
        monitor_parent_tick
        sleep 1
      end
    end
  end

  def monitor_parent_tick
    supervisor = Demon::Base.handoff_supervisor_pid

    if !(supervisor ? Demon::Base.running?(supervisor) : alive?(@parent_pid))
      Process.kill "TERM", Process.pid
      sleep(supervisor ? stop_timeout : 10)
      Process.kill "KILL", Process.pid
    end
  rescue Exception => e
    log_error(e)
  end

  def log_error(e)
    log("URGENT monitoring thread had an exception #{e.class}: #{e.message}", level: :error)
  rescue Exception
    # Fall back to STDERR if the logger is broken
    begin
      $stderr.puts("[#{self.class}##{Process.pid}] monitor-parent: #{e.class}: #{e.message}")
    rescue StandardError
    end
  end

  def suppress_stdout
    true
  end

  def suppress_stderr
    true
  end

  def establish_app
    Discourse.after_fork if defined?(Discourse)

    Signal.trap("HUP") do
      delete_pid_file
    ensure
      # TERM is way cleaner than exit
      Process.kill("TERM", Process.pid)
    end

    # keep stuff simple for now
    $stdout.reopen("/dev/null", "w") if suppress_stdout
    $stderr.reopen("/dev/null", "w") if suppress_stderr
  end

  def after_fork
  end
end
