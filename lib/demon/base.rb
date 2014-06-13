module Demon; end

# intelligent fork based demonizer
class Demon::Base

  def self.start(count=1)
    @demons ||= {}
    count.times do |i|
      (@demons["#{prefix}_#{i}"] ||= new(i)).start
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

  def initialize(index)
    @index = index
    @pid = nil
    @parent_pid = Process.pid
    @started = false
  end

  def pid_file
    "#{Rails.root}/tmp/pids/#{self.class.prefix}_#{@index}.pid"
  end

  def stop
    @started = false
    if @pid
      Process.kill("HUP",@pid)
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
      Process.kill("TERM",existing)
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
      if alive?(pid)
        return pid
      end
    end

    nil
  end

  private

  def write_pid_file
    FileUtils.mkdir_p(Rails.root + "tmp/pids")
    File.open(pid_file,'w') do |f|
      f.write(@pid)
    end
  end

  def delete_pid_file
    File.delete(pid_file)
  end

  def monitor_parent
    Thread.new do
      while true
        unless alive?(@parent_pid)
          Process.kill "TERM", Process.pid
          sleep 10
          Process.kill "KILL", Process.pid
        end
        sleep 1
      end
    end
  end

  def alive?(pid)
    begin
      Process.kill(0, pid)
      true
    rescue
      false
    end
  end

  def suppress_stdout
    true
  end

  def suppress_stderr
    true
  end

  def establish_app
    Discourse.after_fork

    Signal.trap("HUP") do
      begin
        delete_pid_file
      ensure
        exit
      end
    end

    # keep stuff simple for now
    $stdout.reopen("/dev/null", "w") if suppress_stdout
    $stderr.reopen("/dev/null", "w") if suppress_stderr
  end

  def after_fork
  end
end
