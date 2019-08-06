# frozen_string_literal: true

module TurboTests
  class Runner
    def self.run(opts = {})
      files = opts[:files]
      formatters = opts[:formatters]
      start_time = opts.fetch(:start_time) { Time.now }
      verbose = opts.fetch(:verbose, false)

      if verbose
        STDERR.puts "VERBOSE"
      end

      reporter = Reporter.from_config(formatters, start_time)

      new(
        reporter: reporter,
        files: files,
        verbose: verbose
      ).run
    end

    def initialize(opts)
      @reporter = opts[:reporter]
      @files = opts[:files]
      @verbose = opts[:verbose]

      @messages = Queue.new
      @threads = []
    end

    def run
      check_for_migrations

      @num_processes = ParallelTests.determine_number_of_processes(nil)

      tests_in_groups =
        ParallelTests::RSpec::Runner.tests_in_groups(
          @files,
          @num_processes,
          group_by: :filesize
        )

      setup_tmp_dir

      tests_in_groups.each_with_index do |tests, process_num|
        start_subprocess(tests, process_num + 1)
      end

      handle_messages

      @reporter.finish

      @threads.each(&:join)

      @reporter.failed_examples.empty?
    end

    protected

    def check_for_migrations
      config =
        ActiveRecord::Base
          .configurations["test"]
          .merge("database" => "discourse_test_1")

      conn = ActiveRecord::Base.establish_connection(config).connection
      begin
        ActiveRecord::Migration.check_pending!(conn)
      rescue ActiveRecord::PendingMigrationError
        puts "There are pending migrations, run rake parallel:migrate"
        exit 1
      end
    end

    def setup_tmp_dir
      begin
        FileUtils.rm_r('tmp/test-pipes')
      rescue Errno::ENOENT
      end

      FileUtils.mkdir_p('tmp/test-pipes/')
    end

    def start_subprocess(tests, process_num)
      if tests.empty?
        @messages << {
          type: 'exit',
          process_num: process_num
        }
      else
        begin
          File.mkfifo("tmp/test-pipes/subprocess-#{process_num}")
        rescue Errno::EEXIST
        end

        env = { 'TEST_ENV_NUMBER' => process_num.to_s }
        command = [
          "bundle", "exec", "rspec",
          "-f", "TurboTests::JsonRowsFormatter",
          "-o", "tmp/test-pipes/subprocess-#{process_num}",
          *tests
        ]

        if @verbose
          command_str = [
            env.map { |k, v| "#{k}=#{v}" }.join(' '),
            command.join(' ')
          ].join(' ')

          STDERR.puts "Process #{process_num}: #{command_str}"
        end

        _stdin, stdout, stderr, _wait_thr = Open3.popen3(env, *command)

        @threads <<
          Thread.new do
            File.open("tmp/test-pipes/subprocess-#{process_num}") do |fd|
              fd.each_line do |line|
                message = JSON.parse(line)
                message = message.symbolize_keys
                message[:process_num] = process_num
                @messages << message
              end
            end

            @messages << { type: 'exit', process_num: process_num }
          end

        @threads << start_copy_thread(stdout, STDOUT)
        @threads << start_copy_thread(stderr, STDERR)
      end
    end

    def start_copy_thread(src, dst)
      Thread.new do
        while true
          begin
            msg = src.readpartial(4096)
          rescue EOFError
            break
          else
            dst.write(msg)
          end
        end
      end
    end

    def handle_messages
      exited = 0

      begin
        while true
          message = @messages.pop
          case message[:type]
          when 'example_passed'
            example = FakeExample.from_obj(message[:example])
            @reporter.example_passed(example)
          when 'example_pending'
            example = FakeExample.from_obj(message[:example])
            @reporter.example_pending(example)
          when 'example_failed'
            example = FakeExample.from_obj(message[:example])
            @reporter.example_failed(example)
          when 'seed'
          when 'close'
          when 'exit'
            exited += 1
            if exited == @num_processes
              break
            end
          else
            STDERR.puts("Unhandled message in main process: #{message}")
          end

          STDOUT.flush
        end
      rescue Interrupt
      end
    end
  end
end
