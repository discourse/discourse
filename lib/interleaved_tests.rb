require 'open3'
require 'fileutils'
require 'json'
require 'rspec'
require 'rails'

require 'parallel_tests'
require 'parallel_tests/rspec/runner'

module InterleavedTests
  class Reporter
    def self.from_config(formatter_config)
      reporter = new

      formatter_config.each do |config|
        name, outputs = config.values_at(:name, :outputs)

        outputs.map! do |filename|
          if filename == '-'
            STDOUT
          else
            File.open(filename, 'w')
          end
        end

        reporter.add(name, outputs)
      end

      reporter
    end

    attr_reader :pending_examples
    attr_reader :failed_examples
    attr_reader :all_examples

    def initialize
      @formatters = []
      @pending_examples = []
      @failed_examples = []
      @all_examples = []
    end

    def add(name, outputs)
      outputs.each do |output|
        formatter_class =
          case name
          when 'p', 'progress'
            RSpec::Core::Formatters::ProgressFormatter
          else
            Kernel.const_get(name)
          end

        @formatters << formatter_class.new(output)
      end
    end

    def example_passed(example)
      notification = example.notification

      @formatters.each do |formatter|
        formatter.example_passed(notification) if formatter.respond_to?(:example_passed)
      end

      @all_examples << example
    end

    def example_pending(example)
      notification = example.notification

      @formatters.each do |formatter|
        formatter.example_pending(notification) if formatter.respond_to?(:example_pending)
      end

      @all_examples << example
      @pending_examples << example
    end

    def example_failed(example)
      notification = example.notification

      @formatters.each do |formatter|
        formatter.example_failed(notification) if formatter.respond_to?(:example_failed)
      end

      @all_examples << example
      @failed_examples << example
    end

    def method_missing(method, arg)
      @formatters.each do |formatter|
        formatter.send(method, arg) if formatter.respond_to?(method)
      end
    end
  end

  FakeException = Struct.new(:backtrace, :message, :cause)
  class FakeException
    def self.from_obj(obj)
      if obj
        obj = obj.symbolize_keys
        new(
          obj[:backtrace],
          obj[:message],
          obj[:cause]
        )
      end
    end
  end

  FakeExecutionResult = Struct.new(:example_skipped?, :pending_message, :status, :pending_fixed?, :exception)
  class FakeExecutionResult
    def self.from_obj(obj)
      obj = obj.symbolize_keys
      new(
        obj[:example_skipped?],
        obj[:pending_message],
        obj[:status].to_sym,
        obj[:pending_fixed?],
        FakeException.from_obj(obj[:exception])
      )
    end
  end

  FakeExample = Struct.new(:execution_result, :location, :full_description, :metadata, :location_rerun_argument)
  class FakeExample
    def self.from_obj(obj)
      obj = obj.symbolize_keys
      new(
        FakeExecutionResult.from_obj(obj[:execution_result]),
        obj[:location],
        obj[:full_description],
        obj[:metadata].symbolize_keys,
        obj[:location_rerun_argument],
      )
    end

    def notification
      RSpec::Core::Notifications::ExampleNotification.for(
        self
      )
    end
  end

  def self.run(formatter_config, files)
    start_time = Time.now

    reporter = Reporter.from_config(formatter_config)

    num_processes = ParallelTests.determine_number_of_processes(nil)

    tests_in_groups =
      ParallelTests::RSpec::Runner.tests_in_groups(
        files,
        num_processes,
        group_by: :filesize
      )

    messages = Queue.new

    begin
      FileUtils.rm_r('tmp/test-pipes')
    rescue Errno::ENOENT
    end

    FileUtils.mkdir_p('tmp/test-pipes/')

    tests_in_groups.each_with_index do |tests, process_num|
      process_num += 1

      if tests.empty?
        messages << {type: 'exit', process_num: process_num}
      else
        begin
          File.mkfifo("tmp/test-pipes/subprocess-#{process_num}")
        rescue Errno::EEXIST
        end

        stdin, stdout, stderr, wait_thr =
          Open3.popen3(
            {'TEST_ENV_NUMBER' => process_num.to_s},
            "bundle", "exec", "rspec",
            "-f", "JsonRowsFormatter",
            "-o", "tmp/test-pipes/subprocess-#{process_num}",
            *tests
          )

        Thread.new do
          File.open("tmp/test-pipes/subprocess-#{process_num}") do |fd|
            fd.each_line do |line|
              message = JSON.parse(line)
              message = message.symbolize_keys
              message[:process_num] = process_num
              messages << message
            end
          end

          messages << {type: 'exit', process_num: process_num}
        end

        Thread.new do
          while true
            begin
              msg = stdout.readpartial(4096)
            rescue EOFError
              break
            else
              STDOUT.write(msg)
            end
          end
        end

        Thread.new do
          while true
            begin
              msg = stderr.readpartial(4096)
            rescue EOFError
              break
            else
              STDERR.write(msg)
            end
          end
        end
      end
    end

    exited = 0

    seeds = {}

    begin
      while true
        message = messages.pop
        case message[:type]
        when 'example_passed'
          example = FakeExample.from_obj(message[:example])
          reporter.example_passed(example)
        when 'example_pending'
          example = FakeExample.from_obj(message[:example])
          reporter.example_pending(example)
        when 'example_failed'
          example = FakeExample.from_obj(message[:example])
          reporter.example_failed(example)
        when 'seed'
          seeds[message[:process_num]] = message[:seed]
        when 'close'
        when 'exit'
          exited += 1
          if exited == num_processes
            break
          end
        else
          STDERR.puts("Unhandled message in main process: #{message}")
        end

        STDOUT.flush
      end
    rescue Interrupt
    end

    end_time = Time.now

    reporter.start_dump(
      RSpec::Core::Notifications::NullNotification
    )

    reporter.dump_pending(
      RSpec::Core::Notifications::ExamplesNotification.new(
        reporter
      )
    )
    reporter.dump_failures(
      RSpec::Core::Notifications::ExamplesNotification.new(
        reporter
      )
    )
    reporter.dump_summary(
      RSpec::Core::Notifications::SummaryNotification.new(
        end_time - start_time,
        reporter.all_examples,
        reporter.failed_examples,
        reporter.pending_examples,
        0,
        0
      )
    )
    reporter.close(
      RSpec::Core::Notifications::NullNotification
    )
  end
end
