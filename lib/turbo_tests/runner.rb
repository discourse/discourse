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

      STDOUT.puts "VERBOSE" if verbose

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
      @seed = opts[:seed]
      @profile = opts[:profile]
      @retry_and_log_flaky_tests = opts[:retry_and_log_flaky_tests]
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
        ParallelTests::RSpec::Runner.tests_in_groups(@files, @num_processes, **group_opts)

      setup_tmp_dir

      @reporter.add_formatter(Flaky::FailuresLoggerFormatter.new) if @retry_and_log_flaky_tests

      subprocess_opts = { record_runtime: @use_runtime_info }

      start_multisite_subprocess(@files, **subprocess_opts)

      tests_in_groups.each_with_index do |tests, process_id|
        start_regular_subprocess(tests, process_id + 1, **subprocess_opts)
      end

      @reporter.start

      handle_messages

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
      config =
        ActiveRecord::Base
          .configurations
          .find_db_config("test")
          .configuration_hash
          .merge("database" => "discourse_test_1")

      ActiveRecord::Tasks::DatabaseTasks.migrations_paths = %w[db/migrate db/post_migrate]

      begin
        ActiveRecord::Migration.check_all_pending!
      rescue ActiveRecord::PendingMigrationError
        puts "There are pending migrations, run rake parallel:migrate"
        exit 1
      end
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

        if enable_yjit = ENV["RUBY_YJIT_ENABLE"]
          env["RUBY_YJIT_ENABLE"] = enable_yjit
        end

        command_string = [env.map { |k, v| "#{k}=#{v}" }.join(" "), command.join(" ")].join(" ")

        if @verbose
          STDOUT.puts "::group::[#{process_id}] Run RSpec" if ENV["GITHUB_ACTIONS"]
          STDOUT.puts "Process #{process_id}: #{command_string}"
          STDOUT.puts "::endgroup::" if ENV["GITHUB_ACTIONS"]
        end

        stdin, stdout, stderr, wait_thr = Open3.popen3(env, *command)
        stdin.close

        @threads << Thread.new do
          File.open(tmp_filename) do |fd|
            fd.each_line do |line|
              message = JSON.parse(line)
              message = message.symbolize_keys
              message[:process_id] = process_id
              message[:command_string] = command_string
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
              @reporter.message("[#{message[:process_id]}] DONE (#{exited}/#{@num_processes + 1})")
            end

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
