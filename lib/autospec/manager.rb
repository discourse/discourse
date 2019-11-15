# frozen_string_literal: true

require "listen"
require "thread"
require "fileutils"
require "autospec/reload_css"
require "autospec/base_runner"
require "socket_server"

module Autospec; end

class Autospec::Manager

  def self.run(opts = {})
    self.new(opts).run
  end

  def initialize(opts = {})
    @opts = opts
    @debug = opts[:debug]
    @auto_run_all = ENV["AUTO_RUN_ALL"] != "0"
    @queue = []
    @mutex = Mutex.new
    @signal = ConditionVariable.new
    @runners = [ruby_runner]

    if ENV["QUNIT"] == "1"
      @runners << javascript_runner
    else
      puts "Skipping JS tests, run them in the browser at /qunit or add QUNIT=1 to env"
    end
  end

  def run
    Signal.trap("HUP") { stop_runners; exit }

    Signal.trap("INT") do
      begin
        stop_runners
      rescue => e
        puts "FAILED TO STOP RUNNERS #{e}"
      end
      exit
    end

    ensure_all_specs_will_run if @auto_run_all
    start_runners
    start_service_queue
    listen_for_changes

    puts "Press [ENTER] to stop the current run"
    puts "Press [ENTER] while stopped to run all specs" unless @auto_run_all
    while @runners.any?(&:running?)
      STDIN.gets
      process_queue
    end

  rescue => e
    fail(e, "failed in run")
  ensure
    stop_runners
  end

  private

  def ruby_runner
    require "autospec/simple_runner"
    Autospec::SimpleRunner.new
  end

  def javascript_runner
    require "autospec/qunit_runner"
    Autospec::QunitRunner.new
  end

  def ensure_all_specs_will_run(current_runner = nil)
    puts "@@@@@@@@@@@@ ensure_all_specs_will_run" if @debug

    @queue.reject! { |_, s, _| s == "spec" }

    if current_runner
      @queue.concat [['spec', 'spec', current_runner]]
    end

    @runners.each do |runner|
      @queue.concat [['spec', 'spec', runner]] unless @queue.any? { |_, s, r| s == "spec" && r == runner }
    end
  end

  [:start, :stop, :abort].each do |verb|
    define_method("#{verb}_runners") do
      puts "@@@@@@@@@@@@ #{verb}_runners" if @debug
      @runners.each(&verb)
    end
  end

  def start_service_queue
    puts "@@@@@@@@@@@@ start_service_queue" if @debug
    Thread.new do
      while true
        thread_loop
      end
    end
  end

  # the main loop, will run the specs in the queue till one fails or the queue is empty
  def thread_loop
    puts "@@@@@@@@@@@@ thread_loop" if @debug
    @mutex.synchronize do
      current = @queue.first
      last_failed = false
      last_failed = process_spec(current) if current
      # stop & wait for the queue to have at least one item or when there's been a failure
      if @debug
        puts "@@@@@@@@@@@@ waiting because..."
        puts "@@@@@@@@@@@@ ...current spec has failed" if last_failed
        puts "@@@@@@@@@@@@ ...queue is empty" if @queue.length == 0
      end
      @signal.wait(@mutex) if @queue.length == 0 || last_failed
    end
  rescue => e
    fail(e, "failed in main loop")
  end

  # will actually run the spec and check whether the spec has failed or not
  def process_spec(current)
    puts "@@@@@@@@@@@@ process_spec --> #{current}" if @debug
    has_failed = false
    # retrieve the instance of the runner
    runner = current[2]
    # actually run the spec (blocking call)
    result = runner.run(current[1]).to_i

    if result == 0
      puts "@@@@@@@@@@@@ success" if @debug
      # remove the spec from the queue
      @queue.shift
    else
      puts "@@@@@@@@@@@@ failure" if @debug
      has_failed = true
      if result > 0
        focus_on_failed_tests(current)
        ensure_all_specs_will_run(runner) if @auto_run_all
      end
    end

    has_failed
  end

  def focus_on_failed_tests(current)
    puts "@@@@@@@@@@@@ focus_on_failed_tests --> #{current}" if @debug
    runner = current[2]
    # we only want 1 focus in the queue
    @queue.shift if current[0] == "focus"
    # focus on the first 10 failed specs
    failed_specs = runner.failed_specs[0..10]
    puts "@@@@@@@@@@@@ failed_specs --> #{failed_specs}" if @debug

    # try focus tag
    if failed_specs.length > 0
      filename, _ = failed_specs[0].split(":")
      if filename && File.exist?(filename) && !File.directory?(filename)
        spec = File.read(filename)
        start, _ = spec.split(/\S*#focus\S*$/)
        if start.length < spec.length
          line = start.scan(/\n/).length + 1
          puts "Found #focus tag on line #{line}!"
          failed_specs = ["#{filename}:#{line + 1}"]
        end
      end
    end

    # focus on the failed specs
    @queue.unshift ["focus", failed_specs.join(" "), runner] if failed_specs.length > 0
  end

  def root_path
    root_path ||= File.expand_path(File.dirname(__FILE__) + "../../..")
  end

  def reverse_symlink_map
    map = {}
    Dir[root_path + "/plugins/*"].each do |f|
      next if !File.directory? f
      resolved = File.realpath(f)
      if resolved != f
        map[resolved] = f
      end
    end
    map
  end

  # plugins can be symlinked, try to figure out which plugin this is
  def reverse_symlink(file)
    resolved = file
    @reverse_map ||= reverse_symlink_map
    @reverse_map.each do |location, discourse_location|
      if file.start_with?(location)
        resolved = discourse_location + file[location.length..-1]
      end
    end

    resolved
  end

  def listen_for_changes
    puts "@@@@@@@@@@@@ listen_for_changes" if @debug

    options = {
      ignore: /^lib\/autospec/,
    }

    if @opts[:force_polling]
      options[:force_polling] = true
      options[:latency] = @opts[:latency] || 3
    end

    path = root_path

    if ENV['VIM_AUTOSPEC']
      STDERR.puts "Using VIM file listener"

      socket_path = (Rails.root + "tmp/file_change.sock").to_s
      FileUtils.rm_f(socket_path)
      server = SocketServer.new(socket_path)
      server.start do |line|
        file, line = line.split(' ')
        file = reverse_symlink(file)
        file = file.sub(Rails.root.to_s + "/", "")
        # process_change can aquire a mutex and block
        # the acceptor
        Thread.new do
          if file =~ /(es6|js)$/
            process_change([[file]])
          else
            process_change([[file, line]])
          end
        end
        "OK"
      end
      return
    end

    # to speed up boot we use a thread
    ["spec", "lib", "app", "config", "test", "vendor", "plugins"].each do |watch|

      puts "@@@@@@@@@ Listen to #{path}/#{watch} #{options}" if @debug
      Thread.new do
        begin
          listener = Listen.to("#{path}/#{watch}", options) do |modified, added, _|
            paths = [modified, added].flatten
            paths.compact!
            paths.map! do |long|
              long = reverse_symlink(long)
              long[(path.length + 1)..-1]
            end
            process_change(paths)
          end
          listener.start
          sleep
        rescue => e
          puts "FAILED to listen on changes to #{path}/#{watch}"
          puts e
        end
      end
    end

  end

  def process_change(files)
    return if files.length == 0

    puts "@@@@@@@@@@@@ process_change --> #{files}" if @debug

    specs = []
    hit = false

    files.each do |file, line|
      @runners.each do |runner|
        # reloaders
        runner.reloaders.each do |k|
          if k.match(file)
            puts "@@@@@@@@@@@@ #{file} matched a reloader for #{runner}" if @debug
            runner.reload
            return
          end
        end
        # watchers
        runner.watchers.each do |k, v|
          if m = k.match(file)
            puts "@@@@@@@@@@@@ #{file} matched a watcher for #{runner}" if @debug
            hit = true
            spec = v ? (v.arity == 1 ? v.call(m) : v.call) : file
            with_line = spec
            if spec == file && line
              with_line = spec + ":" << line.to_s
            end
            if File.exists?(spec) || Dir.exists?(spec)
              if with_line != spec
                specs << [file, spec, runner]
              end
              specs << [file, with_line, runner]
            end
          end
        end
      end
    end
    queue_specs(specs) if hit
  rescue => e
    fail(e, "failed in watcher")
  end

  def queue_specs(specs)
    puts "@@@@@@@@@@@@ queue_specs --> #{specs}" if @debug

    if specs.length == 0
      locked = @mutex.try_lock
      if locked
        @signal.signal
        @mutex.unlock
      end
      return
    else
      abort_runners
    end

    puts "@@@@@@@@@@@@ waiting for the mutex" if @debug
    @mutex.synchronize do
      puts "@@@@@@@@@@@@ queueing specs" if @debug
      puts "@@@@@@@@@@@@ #{@queue}" if @debug
      specs.each do |file, spec, runner|
        # make sure there's no other instance of this spec in the queue
        @queue.delete_if { |_, s, r| s.strip.start_with?(spec.strip) && r == runner }
        # deal with focused specs
        if @queue.first && @queue.first[0] == "focus"
          focus = @queue.shift
          @queue.unshift([file, spec, runner])
          unless spec.include?(":") && focus[1].include?(spec.split(":")[0])
            if focus[1].include?(spec) || file != spec
              @queue.unshift(focus)
            end
          end
        else
          @queue.unshift([file, spec, runner])
        end

        # push run all specs to end of queue in correct order
        ensure_all_specs_will_run(runner) if @auto_run_all
      end
      puts "@@@@@@@@@@@@ specs queued" if @debug
      puts "@@@@@@@@@@@@ #{@queue}" if @debug
      @signal.signal
    end
  end

  def process_queue
    puts "@@@@@@@@@@@@ process_queue" if @debug
    if @queue.length == 0
      puts "@@@@@@@@@@@@ queue is empty..." if @debug
      ensure_all_specs_will_run
      @signal.signal
    else
      current = @queue.first
      runner = current[2]
      specs = runner.failed_specs
      puts
      puts
      if specs.length == 0
        puts "No specs have failed yet! Aborting anyway"
        puts
        abort_runners
      else
        puts "The following specs have failed:"
        specs.each { |s| puts s }
        puts
        specs = specs.map { |s| [s, s, runner] }
        queue_specs(specs)
      end
    end
  end

  def fail(exception, message = nil)
    puts message if message
    puts exception.message
    puts exception.backtrace.join("\n")
  end

end
