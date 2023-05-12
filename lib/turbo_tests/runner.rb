# frozen_string_literal: true

module TurboTests
  class Runner
    def self.run(opts = {})
      files = opts[:files]
      formatters = opts[:formatters]
      start_time = opts.fetch(:start_time) { Time.now }
      verbose = opts.fetch(:verbose, false)
      fail_fast = opts.fetch(:fail_fast, nil)
      use_runtime_info = opts.fetch(:use_runtime_info, false)

      STDERR.puts "VERBOSE" if verbose

      reporter = Reporter.from_config(formatters, start_time)

      new(
        reporter: reporter,
        files: files,
        verbose: verbose,
        fail_fast: fail_fast,
        use_runtime_info: use_runtime_info,
      ).run
    end

    def self.default_spec_folders
      # We do not want to include system specs by default, they are quite slow.
      Dir
        .entries("#{Rails.root}/spec")
        .reject { |entry| !File.directory?("spec/#{entry}") || %w[.. . system].include?(entry) }
        .map { |entry| "spec/#{entry}" }
    end

    def initialize(opts)
      @reporter = opts[:reporter]
      @files = opts[:files]
      @verbose = opts[:verbose]
      @fail_fast = opts[:fail_fast]
      @use_runtime_info = opts[:use_runtime_info]
      @failure_count = 0

      @messages = Queue.new
      @threads = []
      @error = false
    end

    def run
      check_for_migrations

      @num_processes = ParallelTests.determine_number_of_processes(nil)

      group_opts = {}

      if @use_runtime_info
        group_opts[:runtime_log] = "tmp/turbo_rspec_runtime.log"
      else
        group_opts[:group_by] = :filesize
      end

      tests_in_groups =
        ParallelTests::RSpec::Runner.tests_in_groups(@files, @num_processes, **group_opts)

      setup_tmp_dir

      subprocess_opts = { record_runtime: @use_runtime_info }

      start_multisite_subprocess(@files, **subprocess_opts)

      tests_in_groups.each_with_index do |tests, process_id|
        start_regular_subprocess(tests, process_id + 1, **subprocess_opts)
      end

      handle_messages

      @reporter.finish

      @threads.each(&:join)

      @reporter.failed_examples.empty? && !@error
    end

    protected

    def check_for_migrations
      config =
        ActiveRecord::Base
          .configurations
          .find_db_config("test")
          .configuration_hash
          .merge("database" => "discourse_test_1")

      ActiveRecord::Tasks::DatabaseTasks.migrations_paths = %w[db/migrate db/post_migrate]

      conn = ActiveRecord::Base.establish_connection(config).connection

      begin
        ActiveRecord::Migration.check_pending!(conn)
      rescue ActiveRecord::PendingMigrationError
        puts "There are pending migrations, run rake parallel:migrate"
        exit 1
      ensure
        conn.close
      end
    end

    def setup_tmp_dir
      begin
        FileUtils.rm_r("tmp/test-pipes")
      rescue Errno::ENOENT
      end

      FileUtils.mkdir_p("tmp/test-pipes/")
    end

    def start_multisite_subprocess(tests, **opts)
      start_subprocess({}, %w[--tag type:multisite], tests, "multisite", **opts)
    end

    def start_regular_subprocess(tests, process_id, **opts)
      start_subprocess(
        { "TEST_ENV_NUMBER" => process_id.to_s },
        %w[--tag ~type:multisite],
        tests,
        process_id,
        **opts,
      )
    end

    def start_subprocess(env, extra_args, tests, process_id, record_runtime:)
      if tests.empty?
        @messages << { type: "exit", process_id: process_id }
      else
        tmp_filename = "tmp/test-pipes/subprocess-#{process_id}"

        begin
          File.mkfifo(tmp_filename)
        rescue Errno::EEXIST
        end

        env["RSPEC_SILENCE_FILTER_ANNOUNCEMENTS"] = "1"

        record_runtime_options =
          if record_runtime
            %w[--format ParallelTests::RSpec::RuntimeLogger --out tmp/turbo_rspec_runtime.log]
          else
            []
          end

        command = [
          "bundle",
          "exec",
          "rspec",
          *extra_args,
          "--seed",
          rand(2**16).to_s,
          "--format",
          "TurboTests::JsonRowsFormatter",
          "--out",
          tmp_filename,
          *record_runtime_options,
          *tests,
        ]

        if @verbose
          command_str =
            [env.map { |k, v| "#{k}=#{v}" }.join(" "), command.join(" ")].select { |x| x.size > 0 }
              .join(" ")

          STDERR.puts "Process #{process_id}: #{command_str}"
        end

        stdin, stdout, stderr, wait_thr = Open3.popen3(env, *command)
        stdin.close

        @threads << Thread.new do
          File.open(tmp_filename) do |fd|
            fd.each_line do |line|
              message = JSON.parse(line)
              message = message.symbolize_keys
              message[:process_id] = process_id
              @messages << message
            end
          end

          @messages << { type: "exit", process_id: process_id }
        end

        @threads << start_copy_thread(stdout, STDOUT)
        @threads << start_copy_thread(stderr, STDERR)

        @threads << Thread.new { @messages << { type: "error" } if wait_thr.value.exitstatus != 0 }
      end
    end

    def start_copy_thread(src, dst)
      Thread.new do
        while true
          begin
            msg = src.readpartial(4096)
          rescue EOFError
            src.close
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
          when "example_passed"
            example = FakeExample.from_obj(message[:example], message[:process_id])
            @reporter.example_passed(example)
          when "example_pending"
            example = FakeExample.from_obj(message[:example], message[:process_id])
            @reporter.example_pending(example)
          when "example_failed"
            example = FakeExample.from_obj(message[:example], message[:process_id])
            @reporter.example_failed(example)
            @failure_count += 1
            if fail_fast_met
              @threads.each(&:kill)
              break
            end
          when "message"
            @reporter.message(message[:message])
          when "seed"
          when "close"
          when "error"
            @reporter.error_outside_of_examples
            @error = true
          when "exit"
            exited += 1
            @reporter.message("[#{message[:process_id]}] DONE (#{exited}/#{@num_processes + 1})")
            break if exited == @num_processes + 1
          else
            STDERR.puts("Unhandled message in main process: #{message}")
          end

          STDOUT.flush
        end
      rescue Interrupt
      end
    end

    def fail_fast_met
      !@fail_fast.nil? && @failure_count >= @fail_fast
    end
  end
end
