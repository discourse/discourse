require "listen"
require "thread"
require "fileutils"
require "autospec/reload_css"
require "autospec/base_runner"

module Autospec; end

class Autospec::Manager

  def self.run(opts={})
    self.new(opts).run
  end

  def initialize(opts = {})
    @opts = opts
    @debug = opts[:debug]
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
    Signal.trap("INT") { stop_runners; exit }

    ensure_all_specs_will_run
    start_runners
    start_service_queue
    listen_for_changes

    puts "Press [ENTER] to stop the current run"
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
    if ENV["SPORK"]
      require "autospec/spork_runner"
      Autospec::SporkRunner.new
    else
      require "autospec/simple_runner"
      Autospec::SimpleRunner.new
    end
  end

  def javascript_runner
    require "autospec/qunit_runner"
    Autospec::QunitRunner.new
  end

  def ensure_all_specs_will_run
    puts "@@@@@@@@@@@@ ensure_all_specs_will_run" if @debug
    @runners.each do |runner|
      @queue << ['spec', 'spec', runner] unless @queue.any? { |_, s, r| s == "spec" && r == runner }
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
        ensure_all_specs_will_run
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
    puts "@@@@@@@@@@@@ failed_spces --> #{failed_specs}" if @debug
    # focus on the failed specs
    @queue.unshift ["focus", failed_specs.join(" "), runner] if failed_specs.length > 0
  end

  def listen_for_changes
    puts "@@@@@@@@@@@@ listen_for_changes" if @debug

    options = {
      ignore: /^public|^lib\/autospec/,
      relative_paths: true,
    }

    if @opts[:force_polling]
      options[:force_polling] = true
      options[:latency] = @opts[:latency] || 3
    end

    Thread.start do
      Listen.to('.', options) do |modified, added, _|
        process_change([modified, added].flatten.compact)
      end
    end
  end

  def process_change(files)
    return if files.length == 0

    puts "@@@@@@@@@@@@ process_change --> #{files}" if @debug

    specs = []
    hit = false

    files.each do |file|
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
        runner.watchers.each do |k,v|
          if m = k.match(file)
            puts "@@@@@@@@@@@@ #{file} matched a watcher for #{runner}" if @debug
            hit = true
            spec = v ? (v.arity == 1 ? v.call(m) : v.call) : file
            specs << [file, spec, runner] if File.exists?(spec) || Dir.exists?(spec)
          end
        end
      end
      # special watcher for styles/templates
      Autospec::ReloadCss::WATCHERS.each do |k, _|
        matches = []
        matches << file if k.match(file)
        Autospec::ReloadCss.run_on_change(matches) if matches.present?
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
        @queue.delete_if { |_, s, r| s.strip == spec.strip && r == runner }
        # deal with focused specs
        if @queue.first && @queue.first[0] == "focus"
          focus = @queue.shift
          @queue.unshift([file, spec, runner])
          if focus[1].include?(spec) || file != spec
            @queue.unshift(focus)
          end
        else
          @queue.unshift([file, spec, runner])
        end
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
        puts "No specs have failed yet! "
        puts
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
