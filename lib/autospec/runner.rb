require "drb/drb"
require "thread"

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

    start_spork
    Signal.trap("HUP") {stop_spork; exit }
    Signal.trap("SIGINT") {stop_spork; exit }

    Thread.start do
      Listen.to('.', relative_paths: true) do |modified, added, removed|
        process_change([modified, added].flatten.compact)
      end
    end

    @mutex.synchronize do
      @queue << ['spec', 'spec']
      @signal.signal
    end

    Process.wait

  rescue => e
    puts e
    puts e.backtrace
    stop_spork
  end


  def process_change(files)
    return unless files.length > 0
    specs = []
    files.each do |file|
      MATCHERS.each do |k,v|
        if m = k.match(file)
          spec = v ? ( v.arity == 1 ? v.call(m) : v.call   ) : file
          if File.exists?(spec) || Dir.exists?(spec)
            specs << [file, spec]
          end
        end
      end
    end
    queue_specs(specs)
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
          if focus[1].include? spec || c != spec
            @queue << focus
          end
        else
          @queue << [c,spec]
        end
      end
      @signal.signal
    end
  end

  def start_service_queue
    @worker ||= Thread.new do
      while true
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
                # focus
                specs = failed_specs[0..10]
                if current[0] == "focus"
                  @queue.pop
                end
                @queue << ["focus", specs.join(" ")]
              end
            end
          end
          @signal.wait(@mutex) if @queue.length == 0 || last_failed
        end
      end
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

    @spork_pid = Process.spawn("RAILS_ENV=test bundle exec spork")
    write_pid_file(spork_pid_file, @spork_pid)

    running = false
    while !running
      running = spork_running?
      sleep 0.1
    end

  end
end
