# frozen_string_literal: true

module Demon; end

# intelligent fork based demonizer
class Demon::Base

  def self.demons
    @demons
  end

  def self.start(count = 1, verbose: false)
    @demons ||= {}
    count.times do |i|
      (@demons["#{prefix}_#{i}"] ||= new(i, verbose: verbose)).start
    end
  end

  def self.stop
    return unless @demons
    @demons.values.each do |demon|
      demon.stop
    end
  end

  def self.restart
    return unless @demons
    @demons.values.each do |demon|
      demon.stop
      demon.start
    end
  end

  def self.ensure_running
    @demons.values.each do |demon|
      demon.ensure_running
    end
  end

  attr_reader :pid, :parent_pid, :started, :index
  attr_accessor :stop_timeout

  def initialize(index, rails_root: nil, parent_pid: nil, verbose: false)
    @index = index
    @pid = nil
    @parent_pid = parent_pid || Process.pid
    @started = false
    @stop_timeout = 10
    @rails_root = rails_root || Rails.root
    @verbose = verbose
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

  def stop_signal
    "HUP"
  end

  def stop
    @started = false
    if @pid
      Process.kill(stop_signal, @pid)

      wait_for_stop = lambda {
        timeout = @stop_timeout

        while alive? && timeout > 0
          timeout -= (@stop_timeout / 10.0)
          sleep(@stop_timeout / 10.0)
          Process.waitpid(@pid, Process::WNOHANG) rescue -1
        end

        Process.waitpid(@pid, Process::WNOHANG) rescue -1
      }

      wait_for_stop.call

      if alive?
        STDERR.puts "Process would not terminate cleanly, force quitting. pid: #{@pid} #{self.class}"
        Process.kill("KILL", @pid)
      end

      wait_for_stop.call

      @pid = nil
      @started = false
    end
  end

  def ensure_running
    return unless @started

    if !@pid
      @started = false
      start
      return
    end

    dead = Process.waitpid(@pid, Process::WNOHANG) rescue -1
    if dead
      STDERR.puts "Detected dead worker #{@pid}, restarting..."
      @pid = nil
      @started = false
      start
    end
  end

  def start
    return if @pid || @started

    if existing = already_running?
      # should not happen ... so kill violently
      STDERR.puts "Attempting to kill pid #{existing}"
      Process.kill("TERM", existing)
    end

    @started = true
    run
  end

  def run
    if @pid = fork
      write_pid_file
      return
    end

    monitor_parent
    establish_app
    after_fork
  end

  def already_running?
    if File.exists? pid_file
      pid = File.read(pid_file).to_i
      if Demon::Base.alive?(pid)
        return pid
      end
    end

    nil
  end

  def self.alive?(pid)
    Process.kill(0, pid)
    true
  rescue
    false
  end

  private

  def verbose(msg)
    if @verbose
      puts msg
    end
  end

  def write_pid_file
    verbose("writing pid file #{pid_file} for #{@pid}")
    FileUtils.mkdir_p(@rails_root + "tmp/pids")
    File.open(pid_file, 'w') do |f|
      f.write(@pid)
    end
  end

  def delete_pid_file
    File.delete(pid_file)
  end

  def monitor_parent
    Thread.new do
      while true
        begin
          unless alive?(@parent_pid)
            Process.kill "TERM", Process.pid
            sleep 10
            Process.kill "KILL", Process.pid
          end
        rescue => e
          STDERR.puts "URGENT monitoring thread had an exception #{e}"
        end
        sleep 1
      end
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
      begin
        delete_pid_file
      ensure
        # TERM is way cleaner than exit
        Process.kill("TERM", Process.pid)
      end
    end

    # keep stuff simple for now
    $stdout.reopen("/dev/null", "w") if suppress_stdout
    $stderr.reopen("/dev/null", "w") if suppress_stderr
  end

  def after_fork
  end
end
