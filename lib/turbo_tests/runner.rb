# frozen_string_literal: true

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
      ).run
    end

    def initialize(opts)
      @reporter = opts[:reporter]
      @files = opts[:files]
      @verbose = opts[:verbose]
      @fail_fast = opts[:fail_fast]
      @use_runtime_info = opts[:use_runtime_info]
      @seed = opts[:seed]
      @profile = opts[:profile]
      @retry_and_log_flaky_tests = opts[:retry_and_log_flaky_tests]
      @failure_count = 0

      @messages = Queue.new
      @threads = []
      @error = false
      @subprocesses = {}
    end

    def run
      check_for_migrations

      @num_processes = ParallelTests.determine_number_of_processes(nil)

      group_opts = {}
      group_opts[:runtime_log] = "tmp/turbo_rspec_runtime.log" if @use_runtime_info

      tests_in_groups =
        ParallelTests::RSpec::Runner.tests_in_groups(@files, @num_processes, **group_opts)

      setup_tmp_dir

      if ENV["DISCOURSE_TURBO_RSPEC_DYNAMIC_SCHEDULING"] == "1"
        unless @files.any? && @files.all? { |file| file.match?(%r{(?:\A|/)spec/system/}) }
          raise ArgumentError, "Dynamic scheduling requires only system spec files"
        end
        @work_queue =
          WorkQueue.new(
            files: @files,
            worker_count: @num_processes,
            events: @messages,
            runtime_log: @use_runtime_info ? "tmp/turbo_rspec_runtime.log" : nil,
          )
        @work_queue.start
        @reporter.message("Dynamic file sequence: #{@work_queue.sequence_path}; seed: #{@seed}")
      end

      @reporter.add_formatter(Flaky::FailuresLoggerFormatter.new) if @retry_and_log_flaky_tests

      subprocess_opts = { record_runtime: @use_runtime_info }

      start_multisite_subprocess(@files, **subprocess_opts)

      regular_groups = @work_queue ? Array.new(@num_processes) { @files } : tests_in_groups
      regular_groups.each_with_index do |tests, process_id|
        start_regular_subprocess(tests, process_id + 1, **subprocess_opts)
      end

      @reporter.start

      handle_messages

      if @work_queue
        finish_dynamic_subprocesses
        unless @work_queue.complete?
          @dynamic_failure = true
          @reporter.error_outside_of_examples
        end
        @error = true if @subprocesses.values.any? { |thread|
          thread.alive? || !thread.value.success?
        }
      end
      @reporter.finish
      @threads.each(&:join) unless @work_queue

      if @retry_and_log_flaky_tests && @reporter.failed_examples.present? && !@dynamic_failure
        retry_failed_examples_threshold = 10

        if @reporter.failed_examples.length <= retry_failed_examples_threshold
          STDOUT.puts "Retrying failed examples and logging flaky tests..."
          return rerun_failed_examples(@reporter.failed_examples)
        else
          STDOUT.puts "Retry and log flaky tests was enabled but ignored because there are more than #{retry_failed_examples_threshold} failures."
          Flaky::Manager.remove_flaky_tests
        end
      end

      @reporter.failed_examples.empty? && !@error && !@dynamic_failure
    ensure
      @shutdown_thread&.kill
      @work_queue&.close
      if @work_queue
        signal_subprocesses("KILL", groups: true)
        @threads.each { |thread| thread.join(2) }
      end
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

      system(*command)
    end

    def start_multisite_subprocess(tests, **opts)
      start_subprocess({}, %w[--tag type:multisite], tests, "multisite", **opts)
    end

    def start_regular_subprocess(tests, process_id, **opts)
      env = { "TEST_ENV_NUMBER" => process_id.to_s }
      extra_args = %w[--tag ~type:multisite]
      if @work_queue
        env["DISCOURSE_TURBO_RSPEC_WORK_QUEUE"] = @work_queue.path
        extra_args += %w[--require ./lib/turbo_tests/leased_examples]
      end
      start_subprocess(env, extra_args, tests, process_id, **opts)
    end

    def start_subprocess(env, extra_args, tests, process_id, record_runtime:)
      exit_message = {
        type: "exit",
        process_id:,
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

        if @work_queue
          wait_thr = WorkerProcess.new(environment: env, command: command)
          stdin, stdout, stderr = wait_thr.stdin, wait_thr.stdout, wait_thr.stderr
        else
          stdin, stdout, stderr, wait_thr = Open3.popen3(env, *command)
        end
        @subprocesses[process_id] = wait_thr
        stdin.close

        @threads << Thread.new do
          if @work_queue
            read_dynamic_messages(
              filename: tmp_filename,
              wait_thread: wait_thr,
              process_id: process_id,
              command_string: command_string,
            )
          else
            File.open(tmp_filename) do |fd|
              fd.each_line do |line|
                message = JSON.parse(line)
                message = message.symbolize_keys
                message[:process_id] = process_id
                message[:command_string] = command_string
                @messages << message
              end
            end
          end
        ensure
          @messages << exit_message
        end

        @threads << start_copy_thread(stdout, STDOUT)
        @threads << start_copy_thread(stderr, STDERR)

        @threads << Thread.new do
          status = wait_thr.value
          if @work_queue && process_id != "multisite"
            @work_queue.worker_exited(
              worker: process_id,
              status: status.exitstatus || 128 + status.termsig,
            )
          end
          @messages << { type: "error" } unless status.success?
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

    def handle_messages
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
              if @work_queue
                cancel_dynamic_workers
              else
                @threads.each(&:kill)
                break
              end
            end
          when "message"
            @reporter.message(message[:message])
          when "seed"
          when "close"
          when "error"
            @reporter.error_outside_of_examples
            @error = true
          when "dynamic_error"
            @dynamic_failure = true
            @reporter.message("Dynamic scheduling failed: #{message[:message]}")
            cancel_dynamic_workers
          when "dynamic_cancelled"
            @dynamic_failure = true
            cancel_dynamic_workers
          when "exit"
            exited += 1

            if @reporter.formatters.any? { |f| f.is_a?(DocumentationFormatter) }
              duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - message[:start_time]

              @reporter.message(
                "[#{message[:process_id]}] DONE (#{exited}/#{@num_processes + 1}) #{duration.round(2)}s",
              )
            end

            break if exited == @num_processes + 1
          else
            STDERR.puts("Unhandled message in main process: #{message}")
          end

          STDOUT.flush
        end
      rescue Interrupt
        cancel_dynamic_workers if @work_queue
      end
    end

    def cancel_dynamic_workers
      return if @shutdown_thread
      @work_queue.stop
      signal_subprocesses("INT", groups: false)
      @shutdown_thread =
        Thread.new do
          sleep 30
          signal_subprocesses("TERM", groups: true)
          sleep 5
          signal_subprocesses("KILL", groups: true)
        end
    end

    def read_dynamic_messages(filename:, wait_thread:, process_id:, command_string:)
      File.open(filename, File::RDONLY | File::NONBLOCK) do |fd|
        buffer = +""
        loop do
          chunk = fd.read_nonblock(65_536, exception: false)
          if chunk.is_a?(String)
            buffer << chunk
            while (newline = buffer.index("\n"))
              message = JSON.parse(buffer.slice!(0..newline), symbolize_names: true)
              @messages << message.merge(process_id: process_id, command_string: command_string)
            end
          elsif chunk == :wait_readable
            IO.select([fd], nil, nil, 0.25)
          elsif chunk.nil? && !wait_thread.alive?
            raise "Incomplete formatter output" unless buffer.empty?
            break
          else
            sleep 0.01
          end
        end
      end
    rescue StandardError
      @messages << { type: "dynamic_error", message: "worker formatter stream failed" }
    end

    def finish_dynamic_subprocesses
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
      @threads.each do |thread|
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        thread.join(remaining) if remaining > 0
      end
      if @threads.any?(&:alive?)
        @dynamic_failure = true
        signal_subprocesses("KILL", groups: true)
        @threads.each { |thread| thread.join(2) }
      end
    end

    def signal_subprocesses(signal, groups:)
      @subprocesses.each_value { |wait_thread| wait_thread.signal(signal, groups: groups) }
    end

    def fail_fast_met
      !@fail_fast.nil? && @failure_count >= @fail_fast
    end
  end
end
