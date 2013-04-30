require "drb/drb"
require "thread"
require "fileutils"

module Autospec; end

class Autospec::Runner
  MATCHERS = {}
  def self.watch(pattern, &blk)
    MATCHERS[pattern] = blk
  end

  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/components/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }

  # Rails example
  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^app/(.*)(\.erb|\.haml)$})                 { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb" }
  watch(%r{^spec/support/(.+)\.rb$})                  { "spec" }
  watch('app/controllers/application_controller.rb')  { "spec/controllers" }

  # Capybara request specs
  watch(%r{^app/views/(.+)/.*\.(erb|haml)$})          { |m| "spec/requests/#{m[1]}_spec.rb" }


  def self.run
    self.new.run
  end

  def initialize
    @queue = []
    @mutex = Mutex.new
    @signal = ConditionVariable.new
    start_service_queue
  end

  def run

    if already_running?(pid_file)
      puts "autospec appears to be running, it is possible the pid file is old"
      puts "if you are sure it is not running, delete #{pid_file}"
      return
    end
    write_pid_file(pid_file, Process.pid)

    # launching spork is forever going to take longer than this test
    force_polling = true
    Thread.new do
      force_polling = force_polling?
    end

    start_spork
    Signal.trap("HUP") {stop_spork; exit }
    Signal.trap("SIGINT") {stop_spork; exit }

    puts "Forced polling (slower) - inotify does not work on network filesystems, use local filesystem to avoid" if force_polling

    Thread.start do
      Listen.to('.', force_polling: force_polling, filter: /^app|^spec|^lib/, relative_paths: true) do |modified, added, removed|
        process_change([modified, added].flatten.compact)
      end
    end

    @mutex.synchronize do
      @queue << ['spec', 'spec']
      @signal.signal
    end

    Process.wait(@spork_pid)
    puts "Spork has been terminated, exiting"

  rescue => e
    puts e
    puts e.backtrace
    stop_spork
  end

  def wait_for(timeout_milliseconds)
    timeout = (timeout_milliseconds + 0.0) / 1000
    finish = Time.now + timeout
    t = Thread.new do
      while Time.now < finish && !yield
        sleep(0.001)
      end
    end
    t.join rescue nil
  end

  def force_polling?
    works = false

    begin
      require 'rb-inotify'
      n = INotify::Notifier.new
      FileUtils.touch('./tmp/test_polling')

      n.watch("./tmp", :delete){ works = true }
      quit = false
      Thread.new do
        while !works && !quit
          if IO.select([n.to_io], [], [], 0.1)
            n.process
          end
        end
      end
      sleep 0.01
      File.unlink('./tmp/test_polling')

      wait_for(100) { works }
      n.stop
      quit = true
    rescue LoadError
      #assume it works (mac)
      works = true
    end

    !works
  end


  def process_change(files)
    return unless files.length > 0
    specs = []
    hit = false
    files.each do |file|
      MATCHERS.each do |k,v|
        if m = k.match(file)
          hit = true
          spec = v ? ( v.arity == 1 ? v.call(m) : v.call   ) : file
          if File.exists?(spec) || Dir.exists?(spec)
            specs << [file, spec]
          end
        end
      end
    end
    queue_specs(specs) if hit
  rescue => e
    p "failed in watcher"
    p e
    p e.backtrace
  end

  def queue_specs(specs)
    if specs.length == 0
      locked = @mutex.try_lock
      if locked
        @signal.signal
        @mutex.unlock
      end
      return
    else
      spork_service.abort
    end

    @mutex.synchronize do
      specs.each do |c,spec|
        @queue.delete([c,spec])
        if @queue.last && @queue.last[0] == "focus"
          focus = @queue.pop
          @queue << [c,spec]
          if focus[1].include?(spec) || c != spec
            @queue << focus
          end
        else
          @queue << [c,spec]
        end
      end
      @signal.signal
    end
  end

  def thread_loop
    @mutex.synchronize do
      last_failed = false
      current = @queue.last
      if current
        result = run_spec(current[1])
        if result == 0
          @queue.pop
        else
          last_failed = true
          if result.to_i > 0
            focus_on_failed_tests
            ensure_all_specs_will_run
          end
        end
      end
      wait = @queue.length == 0 || last_failed
      @signal.wait(@mutex) if wait
    end
  rescue => e
    p "DISASTA PASTA"
    puts e
    puts e.backtrace
  end

  def start_service_queue
    @worker ||= Thread.new do
      while true
        thread_loop
      end
    end
  end

  def focus_on_failed_tests
    current = @queue.last
    specs = failed_specs[0..10]
    if current[0] == "focus"
      @queue.pop
    end
    @queue << ["focus", specs.join(" ")]
  end

  def ensure_all_specs_will_run
    unless @queue.any?{|s,t| t == 'spec'}
      @queue.unshift(['spec','spec'])
    end
  end

  def failed_specs
    specs = []
    path = './tmp/rspec_result'
    if File.exist?(path)
      specs = File.open(path) { |file| file.read.split("\n") }
      File.delete(path)
    end

    specs
  end

  def run_spec(specs)
    File.delete("tmp/rspec_result") if File.exists?("tmp/rspec_result")
    args = ["-f", "progress", specs.split(" "),
            "-r", "#{File.dirname(__FILE__)}/formatter.rb",
            "-f", "Autospec::Formatter"].flatten

    spork_service.run(args,$stderr,$stdout)
  end


  def spork_pid_file
    Rails.root + "tmp/pids/spork.pid"
  end

  def pid_file
    Rails.root + "tmp/pids/autospec.pid"
  end

  def already_running?(pid_file)
    if File.exists? pid_file
      pid = File.read(pid_file).to_i
      Process.getpgid(pid) rescue nil
    end
  end

  def write_pid_file(file,pid)
    FileUtils.mkdir_p(Rails.root + "tmp/pids")
    File.open(file,'w') do |f|
      f.write(pid)
    end
  end

  def spork_running?
    spork_service.port rescue nil
  end

  def spork_service

    unless @drb_listener_running
      begin
        DRb.start_service("druby://127.0.0.1:0")
      rescue SocketError, Errno::EADDRNOTAVAIL
        DRb.start_service("druby://:0")
      end

      @drb_listener_running = true
    end

    @spork_service ||= DRbObject.new_with_uri("druby://127.0.0.1:8989")
  end

  def stop_spork
    pid = File.read(spork_pid_file).to_i
    Process.kill("SIGHUP",pid)
  end

  def start_spork

    if already_running?(spork_pid_file)
      puts "Killing old orphan spork instance"
      stop_spork
      sleep 1
    end

    @spork_pid = Process.spawn({'RAILS_ENV' => 'test'}, "bundle exec spork")
    write_pid_file(spork_pid_file, @spork_pid)

    running = false
    while !running
      running = spork_running?
      sleep 0.1
    end

  end
end
