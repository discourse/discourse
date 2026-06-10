# frozen_string_literal: true

module TurboTests
  class Runner
    # Canonical runtime log consumed by parallel_tests when splitting specs
    # into balanced groups. It is gitignored, so in CI its only source is the
    # GitHub Actions cache saved at the end of the previous run.
    RUNTIME_LOG = "tmp/turbo_rspec_runtime.log"

    # Every worker used to write its timings to RUNTIME_LOG directly, but
    # ParallelTests::RSpec::LoggerBase opens `--out` with mode "w" in every
    # worker process, each with an independent file offset starting at 0.
    # With 12 workers the last writer overwrites the head of the file and
    # only a byte-overlay mosaic survives — usually too sparse for
    # parallel_tests' runtime threshold (it needs data for > 2/3 of the
    # files), which silently degrades the split to file byte-size, and
    # occasionally just-enough-but-corrupt, which packs the missing heavy
    # files at the average. Each worker now writes to a private log and the
    # parent merges them after all workers exit.
    WORKER_RUNTIME_LOG_DIR = "tmp/turbo_rspec_runtime_logs"

    # Committed snapshot of real measured per-file runtimes, substituted for
    # RUNTIME_LOG when the restored cache is too sparse to balance on (fresh
    # cache scope, or a cache written before the merge fix above) — see
    # #prepare_runtime_log.
    RUNTIME_SEED_LOG = "lib/turbo_tests/core_system_runtime_seed.log"

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
    end

    def run
      check_for_migrations

      @num_processes = ParallelTests.determine_number_of_processes(nil)

      group_opts = {}

      if @use_runtime_info
        prepare_runtime_log
        group_opts[:runtime_log] = RUNTIME_LOG
      end

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

      merge_runtime_logs if @use_runtime_info

      if @retry_and_log_flaky_tests && !@reporter.failed_examples.empty?
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
      # In CI the workflow's `Create and migrate databases` step already
      # runs `parallel:create parallel:migrate` (tests.yml:163-166), which
      # migrates the parent and every worker DB. Re-checking from here
      # only forces the parent to boot Rails — pure overhead on the step's
      # serial-prefix critical path. The caller opts out by setting
      # TURBO_RSPEC_SKIP_MIGRATIONS_CHECK=1; local-dev runs leave it unset
      # and pay the full Rails boot from inside `load_rails_app!`.
      return if ENV["TURBO_RSPEC_SKIP_MIGRATIONS_CHECK"] == "1"

      TurboTests.load_rails_app!
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

      # Drop per-worker runtime logs from a previous run so the merge can't
      # pick up stale timings for a worker slot that doesn't run this time.
      FileUtils.rm_rf(WORKER_RUNTIME_LOG_DIR)
      FileUtils.mkdir_p(WORKER_RUNTIME_LOG_DIR)
    end

    # parallel_tests only balances by runtime when the log covers > 2/3 of
    # the files (ParallelTests::Test::Runner#tests_with_size); below that it
    # silently degrades the split to file byte-size. A cache that clears the
    # bar is fresh, complete, same-environment data — leave it untouched. One
    # that doesn't is a pre-merge-fix byte-overlay mosaic: substitute the
    # committed seed wholesale rather than overlaying, because the two are
    # measured at different scales (CI-contended seconds vs the seed's
    # locally measured seconds) and the grouper packs by relative weight.
    def prepare_runtime_log
      seeded = parse_runtime_log(RUNTIME_SEED_LOG)
      return if seeded.empty?

      cached = parse_runtime_log(RUNTIME_LOG)
      return if cached.count { |path, _| @files.include?(path) } * 1.5 > @files.size

      write_runtime_log(seeded)
    end

    # Fold every worker's private runtime log into RUNTIME_LOG. Entries for
    # files that didn't run this invocation are kept (multiple turbo_rspec
    # invocations within one CI job share the file), fresh timings win.
    def merge_runtime_logs
      fresh =
        Dir["#{WORKER_RUNTIME_LOG_DIR}/*.log"].reduce({}) do |times, path|
          times.merge(parse_runtime_log(path))
        end

      write_runtime_log(parse_runtime_log(RUNTIME_LOG).merge(fresh)) if fresh.any?
    end

    def parse_runtime_log(path)
      return {} unless File.exist?(path)

      File
        .read(path)
        .each_line
        .with_object({}) do |line, times|
          test, _, time = line.strip.rpartition(":")
          # A pre-merge-fix cache can contain one corrupt line at the seam
          # where a worker's write overlapped another's; require a clean
          # `path/to/foo_spec.rb:<float>` shape and drop anything else.
          next if !test.end_with?("_spec.rb") || !time.match?(/\A\d+(\.\d+)?\z/)
          times[test] = time.to_f if time.to_f > 0
        end
    rescue SystemCallError
      {}
    end

    def write_runtime_log(times)
      FileUtils.mkdir_p(File.dirname(RUNTIME_LOG))
      File.write(RUNTIME_LOG, times.map { |test, time| "#{test}:#{time}" }.join("\n") << "\n")
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
      # System specs (under `spec/system/**` or `plugins/**/spec/system/**`)
      # never carry `type: :multisite` by convention. When the input file list
      # is entirely system specs, the multisite worker would otherwise boot
      # the full Rails stack, parse every input file to scan for the tag, and
      # exit without running a single example. Pass an empty list in that
      # case so `start_subprocess` short-circuits via its `if tests.empty?`
      # branch — no rspec process spawns, the exit accounting stays correct,
      # and the CPU it would have consumed during the boot phase stays free
      # for the regular workers.
      multisite_tests = system_specs_only?(tests) ? [] : tests
      start_subprocess({}, %w[--tag type:multisite], multisite_tests, "multisite", **opts)
    end

    def system_specs_only?(tests)
      return false if tests.empty?
      tests.all? { |f| f.match?(%r{(?:\A|/)(?:spec|plugins/[^/]+/spec)/system/}) }
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
            [
              "--format",
              "ParallelTests::RSpec::RuntimeLogger",
              "--out",
              "#{WORKER_RUNTIME_LOG_DIR}/worker-#{process_id}.log",
            ]
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

        @threads << Thread.new do
          File.open(tmp_filename) do |fd|
            fd.each_line do |line|
              message = JSON.parse(line)
              message = message.transform_keys(&:to_sym)
              message[:process_id] = process_id
              message[:command_string] = command_string
              @messages << message
            end
          end

          @messages << exit_message
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
      end
    end

    def fail_fast_met
      !@fail_fast.nil? && @failure_count >= @fail_fast
    end
  end
end
