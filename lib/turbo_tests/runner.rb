# frozen_string_literal: true

require "io/nonblock"

module TurboTests
  class Runner
    def self.run(opts = {})
      files = opts[:files]
      formatters = opts[:formatters]
      seed = opts[:seed]
      start_time = opts.fetch(:start_time) { Time.now }
      verbose = opts.fetch(:verbose, false)
      fail_fast = opts.fetch(:fail_fast, nil)
      use_runtime_info = opts.fetch(:use_runtime_info, false)
      retry_and_log_flaky_tests = opts.fetch(:retry_and_log_flaky_tests, false)

      reporter =
        Reporter.from_config(
          formatters,
          start_time,
          max_timings_count: opts[:profile_print_slowest_examples_count],
        )

      if ENV["GITHUB_ACTIONS"]
        RSpec.configure do |config|
          # Enable color output in GitHub Actions
          # This eventually will be `config.color_mode = :on` in RSpec 4?
          config.tty = true
          config.color = true
        end
      end

      new(
        reporter: reporter,
        files: files,
        verbose: verbose,
        fail_fast: fail_fast,
        use_runtime_info: use_runtime_info,
        seed: seed,
        profile: opts[:profile],
        retry_and_log_flaky_tests: retry_and_log_flaky_tests,
        execution_plan_path: opts[:execution_plan_path],
        **opts.slice(:grouping_files),
      ).run
    end

    def initialize(opts)
      @reporter = opts[:reporter]
      @files = opts[:files]
      @grouping_files = opts.fetch(:grouping_files, @files)
      if opts.key?(:grouping_files) &&
           !(
             @grouping_files.is_a?(Array) && @grouping_files.all? { |file| file.is_a?(String) } &&
               @grouping_files.uniq == @grouping_files && (@files - @grouping_files).empty?
           )
        raise ArgumentError, "Grouping inventory must contain every selected test file"
      end
      @verbose = opts[:verbose]
      @fail_fast = opts[:fail_fast]
      @use_runtime_info = opts[:use_runtime_info]
      @seed = opts[:seed]
      @profile = opts[:profile]
      @retry_and_log_flaky_tests = opts[:retry_and_log_flaky_tests]
      @execution_plan_path = opts[:execution_plan_path]
      @failure_count = 0

      @messages = Queue.new
      @threads = []
      @error = false
    end

    def run
      check_for_migrations

      @num_processes = ParallelTests.determine_number_of_processes(nil)

      group_opts = {}
      group_opts[:runtime_log] = "tmp/turbo_rspec_runtime.log" if @use_runtime_info

      tests_in_groups =
        ParallelTests::RSpec::Runner.tests_in_groups(@grouping_files, @num_processes, **group_opts)
      if @grouping_files != @files
        selected = @files.to_h { |file| [file, true] }
        tests_in_groups.map! { |group| group.select { |file| selected.key?(file) } }
      end

      setup_tmp_dir

      @reporter.add_formatter(Flaky::FailuresLoggerFormatter.new) if @retry_and_log_flaky_tests

      workers = {}
      subprocess_opts = { record_runtime: @use_runtime_info, workers: workers }

      collection_batches =
        if ENV["COLLECT_TEST_MAPPING"] == "1"
          batch_size = @files.length.fdiv(@num_processes).ceil.clamp(1, 40)
          tests_in_groups
            .flatten
            .each_slice(batch_size)
            .each_with_index
            .map { |tests, index| [index + 1, tests] }
        end
      expected_exits = collection_batches ? collection_batches.length + 1 : @num_processes + 1

      collection_slots = [@num_processes - 1, 1].max
      start_multisite_subprocess(
        @files,
        **subprocess_opts,
        database_slot: collection_batches ? collection_slots : nil,
      )

      if collection_batches
        (collection_slots - 1).times do |index|
          start_collection_batch(
            process_id: index + 1,
            pending_batches: collection_batches,
            subprocess_opts: subprocess_opts,
          )
        end
      else
        tests_in_groups.each_with_index do |tests, process_id|
          start_regular_subprocess(tests, process_id + 1, **subprocess_opts)
        end
      end
      write_execution_plan(workers)

      @reporter.start

      handle_messages(
        pending_batches: collection_batches,
        subprocess_opts: subprocess_opts,
        expected_exits: expected_exits,
      )

      @reporter.finish

      @threads.each(&:join)

      if @retry_and_log_flaky_tests && @reporter.failed_examples.present?
        retry_failed_examples_threshold = 10

        if @reporter.failed_examples.length <= retry_failed_examples_threshold
          STDOUT.puts "Retrying failed examples and logging flaky tests..."
          return rerun_failed_examples(@reporter.failed_examples)
        else
          STDOUT.puts "Retry and log flaky tests was enabled but ignored because there are more than #{retry_failed_examples_threshold} failures."
          Flaky::Manager.remove_flaky_tests
        end
      end

      @reporter.failed_examples.empty? && !@error
    end

    protected

    def check_for_migrations
      ActiveRecord::Tasks::DatabaseTasks.migrations_paths = %w[db/migrate db/post_migrate]
      ActiveRecord::Migration.check_all_pending!
    rescue ActiveRecord::PendingMigrationError
      STDERR.puts "There are pending migrations, run rake parallel:migrate"
      exit 1
    end

    def setup_tmp_dir
      begin
        FileUtils.rm_r("tmp/test-pipes")
      rescue Errno::ENOENT
      end

      FileUtils.mkdir_p("tmp/test-pipes/")
    end

    def rerun_failed_examples(failed_examples)
      command = [
        "bundle",
        "exec",
        "rspec",
        "--format",
        "documentation",
        "--format",
        "TurboTests::Flaky::FlakyDetectorFormatter",
        *Flaky::Manager.potential_flaky_tests,
      ]

      command += ["--seed", @seed.to_s] if @seed
      system(*command)
    end

    def start_multisite_subprocess(tests, **opts)
      start_subprocess(
        { "TEST_MAPPING_PROCESS_ID" => nil },
        %w[--tag type:multisite],
        tests,
        "multisite",
        **opts,
      )
    end

    def start_regular_subprocess(tests, process_id, identity: process_id, **opts)
      start_subprocess(
        {
          "TEST_ENV_NUMBER" => process_id.to_s,
          "TEST_MAPPING_PROCESS_ID" => identity == process_id ? nil : identity.to_s,
        },
        %w[--tag ~type:multisite],
        tests,
        identity,
        database_slot: identity == process_id ? nil : process_id,
        **opts,
      )
    end

    def start_subprocess(
      env,
      extra_args,
      tests,
      process_id,
      record_runtime:,
      workers:,
      database_slot: nil
    )
      exit_message = {
        type: "exit",
        process_id:,
        database_slot:,
        start_time: Process.clock_gettime(Process::CLOCK_MONOTONIC),
      }

      if tests.empty?
        @messages << exit_message
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
          "--order",
          "random:#{@seed}",
          "--format",
          "TurboTests::JsonRowsFormatter",
          "--out",
          tmp_filename,
          *record_runtime_options,
          *tests,
        ]

        env["DISCOURSE_RSPEC_PROFILE_EACH_EXAMPLE"] = "1" if @profile

        command_string = [env.map { |k, v| "#{k}=#{v}" }.join(" "), command.join(" ")].join(" ")

        if @verbose
          STDOUT.puts "::group::[#{process_id}] Run RSpec" if ENV["GITHUB_ACTIONS"]
          STDOUT.puts "Process #{process_id}: #{command_string}"
          STDOUT.puts "::endgroup::" if ENV["GITHUB_ACTIONS"]
        end

        stdin, stdout, stderr, wait_thr = Open3.popen3(env, *command)
        stdin.close
        pipe_reader = File.open(tmp_filename, File::RDONLY | File::NONBLOCK)
        pipe_writer = File.open(tmp_filename, File::WRONLY | File::NONBLOCK)
        pipe_reader.nonblock = false
        workers[process_id.to_s] = { files: tests, pid: wait_thr.pid }

        reader =
          Thread.new do
            pipe_reader.each_line do |line|
              message = JSON.parse(line)
              message = message.symbolize_keys
              message[:process_id] = process_id
              message[:command_string] = command_string
              @messages << message
            end
          rescue StandardError => error
            @messages << {
              type: "message",
              message: "Could not read test output from process #{process_id}: #{error.message}",
            }
            @messages << { type: "error" }
          ensure
            pipe_reader.close
          end
        @threads << reader
        @threads << start_copy_thread(stdout, STDOUT)
        @threads << start_copy_thread(stderr, STDERR)

        @threads << Thread.new do
          status = wait_thr.value
          pipe_writer.close
          reader.join
          @messages << { type: "error" } if status.exitstatus != 0
          @messages << exit_message
        ensure
          pipe_writer.close unless pipe_writer.closed?
        end
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

    def handle_messages(pending_batches:, subprocess_opts:, expected_exits:)
      exited = 0

      begin
        while true
          message = @messages.pop
          case message[:type]
          when "example_passed"
            example =
              FakeExample.from_obj(
                message[:example],
                process_id: message[:process_id],
                command_string: message[:command_string],
              )

            @reporter.example_passed(example)
          when "example_pending"
            example =
              FakeExample.from_obj(
                message[:example],
                process_id: message[:process_id],
                command_string: message[:command_string],
              )

            @reporter.example_pending(example)
          when "example_failed"
            example =
              FakeExample.from_obj(
                message[:example],
                process_id: message[:process_id],
                command_string: message[:command_string],
              )

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

            if @reporter.formatters.any? { |f| f.is_a?(DocumentationFormatter) }
              duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - message[:start_time]

              @reporter.message(
                "[#{message[:process_id]}] DONE (#{exited}/#{expected_exits}) #{duration.round(2)}s",
              )
            end

            if pending_batches && message[:database_slot]
              start_collection_batch(
                process_id: message.fetch(:database_slot),
                pending_batches: pending_batches,
                subprocess_opts: subprocess_opts,
              )
            end
            break if exited == expected_exits
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

    private

    def write_execution_plan(workers)
      return unless @execution_plan_path
      File.write(@execution_plan_path, JSON.generate(revision: ENV["GITHUB_SHA"], workers: workers))
    end

    def start_collection_batch(process_id:, pending_batches:, subprocess_opts:)
      batch = pending_batches.shift
      return unless batch
      identity, tests = batch
      start_regular_subprocess(
        tests,
        process_id,
        identity: "#{process_id}-#{identity}",
        **subprocess_opts,
      )
      write_execution_plan(subprocess_opts.fetch(:workers))
    end
  end
end
