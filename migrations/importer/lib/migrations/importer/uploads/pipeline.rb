# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # The threading engine shared by all three upload tasks. It owns one
      # producer thread, a pool of worker threads, one writer thread (the sole
      # SQLite writer), the two queues between them, the progress reporting, and
      # SIGINT handling. The tasks stay thin: they only say what to read, how to
      # process one row, and how to write one result.
      #
      # The worker pool is spawned at full size (the plan's ceiling) once, but how
      # many of them may run at a time is governed by a {WorkerGate} that an
      # {AdaptiveController} tunes as it watches CPU, memory, and throughput — no
      # static worker count, because the benchmarks showed the right number depends
      # entirely on the store and the workload. A worker takes a gate permit around
      # each item, so shrinking or growing the pool is just workers parking or
      # waking at the next item boundary — no threads killed or respawned.
      #
      # Rows and results both travel in batches, never one at a time — a per-row
      # SizedQueue handoff costs 2-8x throughput here. The producer fills arrays of
      # up to `batch_size` rows; each worker pops an array, processes it, and hands
      # back an array of results; the writer pops an array, writes each result, and
      # reports progress once for the whole array.
      #
      # A task is any object responding to:
      #   * `title` — the step title shown to the user
      #   * `reporter=` — receives the step handle (for notices from `write`)
      #   * `before_run` / `after_run` — setup and teardown on the main thread
      #   * `max_count` — the progress total (known after `before_run`), or nil
      #   * `store_external?` — whether uploads land on an external store (S3),
      #     which shapes the worker bounds
      #   * `produce(emit_work:, emit_result:)` — the producer body; calls
      #     `emit_work` for rows the workers should process and `emit_result` for
      #     results it already knows (e.g. rows skipped up front)
      #   * `build_worker_resource` — per-worker state (may be nil)
      #   * `process(row, resource)` — returns a result to write, or nil to drop
      #   * `write(result)` — runs only on the writer thread; returns an outcome
      #     symbol (`:ok`, `:skip`, `:warning`, `:error`) for the progress tally
      class Pipeline
        DEFAULT_BATCH_SIZE = 32
        DEFAULT_WORK_QUEUE_SLOTS = 64
        DEFAULT_STATUS_QUEUE_SLOTS = 64

        def initialize(
          task:,
          reporter:,
          batch_size: DEFAULT_BATCH_SIZE,
          work_queue_slots: DEFAULT_WORK_QUEUE_SLOTS,
          status_queue_slots: DEFAULT_STATUS_QUEUE_SLOTS,
          worker_plan: nil,
          sampler: nil,
          adaptive: true,
          controller_interval: AdaptiveController::DEFAULT_INTERVAL,
          with_connection: nil,
          install_trap: true,
          on_double_interrupt: -> { exit!(1) }
        )
          @task = task
          @reporter = reporter
          @batch_size = batch_size
          @work_queue = SizedQueue.new(work_queue_slots)
          @status_queue = SizedQueue.new(status_queue_slots)
          @worker_plan = worker_plan
          @sampler = sampler
          @adaptive = adaptive
          @controller_interval = controller_interval
          @with_connection = with_connection || method(:default_with_connection)
          @install_trap = install_trap
          @on_double_interrupt = on_double_interrupt

          @interrupt_requested = false
          @completed = 0
        end

        # @return [Boolean] whether the run stopped early because of Ctrl-C
        def interrupted?
          @interrupt_requested
        end

        def run
          step = @reporter.start_step(@task.title)
          @task.reporter = step

          begin
            @task.before_run
            @plan = @worker_plan || build_plan
            @gate = WorkerGate.new(target: @plan.seed, max: @plan.ceiling)

            step.with_progress(max_progress: @task.max_count) do |progress|
              @progress = progress
              step.report_concurrency(@gate.target)
              controller = start_controller(step)
              begin
                with_trap { run_threads }
              ensure
                controller&.stop
              end
            end
            @task.after_run
          ensure
            step.finish(outcome: @interrupt_requested ? :interrupted : nil)
          end

          self
        end

        # The trap runs on the main thread and must stay allocation-light — no
        # mutexes. The first Ctrl-C only flips the flag; the producer stops between
        # batches, workers finish their current item, and the writer drains what is
        # left. A second Ctrl-C bails out hard.
        def handle_interrupt
          if @interrupt_requested
            @on_double_interrupt.call
          else
            @interrupt_requested = true
          end
        end

        private

        def run_threads
          writer = start_writer
          workers = start_workers
          producer = start_producer

          producer.join
          @work_queue.close
          workers.each(&:join)
          @status_queue.close
          writer.join
        end

        def start_producer
          Thread.new do
            Thread.current.name = "uploads-producer"
            produce
          end
        end

        def produce
          work_batcher = Batcher.new(@work_queue, @batch_size)
          result_batcher = Batcher.new(@status_queue, @batch_size)

          catch(:stop_producing) do
            @task.produce(
              emit_work: ->(row) { emit(work_batcher, row) },
              emit_result: ->(result) { emit(result_batcher, result) },
            )
          end

          work_batcher.flush
          result_batcher.flush
        end

        def emit(batcher, item)
          batcher.push(item)
          throw :stop_producing if @interrupt_requested
        end

        def start_workers
          Array.new(@gate.max) do |index|
            Thread.new do
              Thread.current.name = "uploads-worker-#{index}"
              work_loop
            end
          end
        end

        def work_loop
          resource = @with_connection.call { @task.build_worker_resource }

          while (batch = @work_queue.pop)
            results = []

            batch.each do |row|
              break if @interrupt_requested

              # Take the permit outside `with_connection`: a worker parked in
              # `acquire` (because the gate shrank) must not pin an AR connection.
              # The permit is held only around one item, so shrinking takes effect
              # within one item's time.
              @gate.acquire
              begin
                result = @with_connection.call { @task.process(row, resource) }
                results << result if result
              ensure
                @gate.release
              end
            end

            @status_queue << results unless results.empty?
            break if @interrupt_requested
          end
        end

        def start_writer
          Thread.new do
            Thread.current.name = "uploads-writer"
            # One lease for the whole thread: some tasks touch ActiveRecord from
            # `write` (e.g. the fixer deleting orphaned uploads), and a manually
            # created thread must hold and release its own connection.
            @with_connection.call { write_loop }
          end
        end

        def write_loop
          while (batch = @status_queue.pop)
            skips = warnings = errors = 0

            batch.each do |result|
              case @task.write(result)
              when :skip
                skips += 1
              when :warning
                warnings += 1
              when :error
                errors += 1
              end
            end

            @progress.update(
              increment_by: batch.size,
              skip_count: skips,
              warning_count: warnings,
              error_count: errors,
            )

            # Single writer thread, so a plain read on the other side (the
            # controller) is safe — it only needs an approximate rate.
            @completed += batch.size
          end
        end

        # --- Adaptive worker sizing. The plan gives the seed and the hard bounds;
        # the gate enforces the live target; the controller moves it. ---

        def build_plan
          AdaptiveController.plan(
            usable_cpus: SystemInfo.usable_cpus,
            store_external: @task.store_external?,
            ar_pool_size: ActiveRecord::Base.connection_pool.size,
            fd_limit: raise_file_limit!,
          )
        end

        # More workers means more open files (tempfiles, store sockets, DB
        # handles), so give the process all the descriptors the OS already allows
        # by lifting the soft limit to the hard one. Best-effort: an unprivileged
        # process can always raise its own soft limit up to the hard cap, but
        # rescue anyway so a locked-down environment doesn't abort the run.
        def raise_file_limit!
          soft, hard = Process.getrlimit(Process::RLIMIT_NOFILE)
          if soft < hard
            Process.setrlimit(Process::RLIMIT_NOFILE, hard, hard)
            soft = hard
          end
          soft
        rescue Errno::EPERM, Errno::EINVAL
          Process.getrlimit(Process::RLIMIT_NOFILE).first
        end

        def start_controller(step)
          return nil unless @adaptive

          controller =
            AdaptiveController.new(
              gate: @gate,
              sampler: @sampler || ResourceSampler.new(usable_cpus: SystemInfo.usable_cpus),
              step:,
              ceiling: @plan.ceiling,
              work_available: -> { !@work_queue.empty? },
              completed_count: -> { @completed },
              interval: @controller_interval,
            )
          controller.start
          controller
        end

        def with_trap
          return yield unless @install_trap

          previous = Signal.trap("INT") { handle_interrupt }
          begin
            yield
          ensure
            Signal.trap("INT", previous)
          end
        end

        # Rails no longer releases connections that manually created threads lease,
        # so each item borrows one and gives it straight back — an idle worker
        # blocked on the queue must not pin a pool slot.
        def default_with_connection(&block)
          ActiveRecord::Base.connection_pool.with_connection(&block)
        end
      end
    end
  end
end
