# frozen_string_literal: true

module Migrations
  module Conversion
    # Runs one step on its own thread for the {StepScheduler}. It forks the step's
    # workers: one for a normal step, several for a partitioned one (or none under
    # `--no-fork`, where the single worker runs inline). Each worker builds the
    # step, opens its own source, reads its rows, and writes them to its own shard.
    #
    # A partitioned step is split into many more chunks than forks. The forks claim
    # them from a shared {ChunkQueue} as they go idle, so a fork with cheap chunks
    # keeps pulling more and the slow ones don't drag out the end. The parent knows
    # the step's total up front, so the workers only report their progress.
    #
    # Once the workers all exit cleanly, the parent hands the shards to the
    # {Consolidator}, which merges them into the run database on a background
    # thread, so the step doesn't wait for its own merge.
    #
    # The parent opens a source only briefly, to work out the plan (the total row
    # count, plus the chunk boundaries for a partitioned step), and closes it before
    # forking. After that only the workers touch the source, and only progress
    # crosses the pipes.
    class StepCoordinator
      class WorkerCrashedError < StandardError
      end

      # How many chunks each fork gets for a partitioned step. More chunks means
      # finer work stealing (a shorter tail) but a bit more overhead. Eight is a
      # good balance.
      CHUNKS_PER_FORK = 8

      attr_reader :step_class

      # @param step_class [Class<Step>] the step this coordinator runs
      # @param step_factory [#call] builds a step from its class, `->(step_class) { step }`;
      #   called inside each worker so the source connection opens there
      # @param reporter [Reporting::Reporter] receives the step's progress and notices
      # @param fork_mutex [Mutex] serialises forking across the run's coordinator threads
      # @param scheduler [StepScheduler] told about a step-level failure for the run summary
      # @param shard_manager [ShardManager] hands out and discards the per-worker shard DBs
      # @param consolidator [Consolidator] merges the finished shards in the background
      # @param fork_count [Integer] how many workers to fork (1 for an unpartitioned step)
      # @param no_fork [Boolean] run the single worker inline instead of forking (`--no-fork`)
      def initialize(
        step_class:,
        step_factory:,
        reporter:,
        fork_mutex:,
        scheduler:,
        shard_manager:,
        consolidator:,
        fork_count: 1,
        no_fork: false
      )
        @step_class = step_class
        @step_factory = step_factory
        @reporter = reporter
        @fork_mutex = fork_mutex
        @scheduler = scheduler
        @shard_manager = shard_manager
        @consolidator = consolidator
        @fork_count = fork_count
        @no_fork = no_fork
      end

      # @return [Symbol] the step's outcome, `:done` or `:failed`
      def run
        @step_handle = @reporter.start_step(@step_class.title)
        outcome = :done
        shards = []
        handed_off = false

        begin
          # `finish` reads `$!` in its ensure, so the work must raise inside this
          # inner begin, before the rescue below clears it.
          begin
            run_workers(shards)
            @consolidator.enqueue(shards)
            handed_off = true
          ensure
            error = $!
            @step_handle.notice(failure_notice(error)) if error.is_a?(StandardError)
            @step_handle.finish
          end
        rescue StandardError => e
          outcome = :failed
          @scheduler.record_failure(@step_class, e)
        ensure
          shards.each { |shard_path| @shard_manager.discard(shard_path) } unless handed_off
        end

        outcome
      end

      private

      def run_workers(shards)
        return run_inline(shards) if @no_fork

        boundaries, total = compute_plan
        worker_count = boundaries.empty? ? 1 : [boundaries.size, @fork_count].min
        # Hand back any forks we won't use (fewer chunks than forks) right away.
        @scheduler.release_forks(@step_class, @fork_count - worker_count)
        @step_handle.report_concurrency(worker_count) if worker_count > 1

        # Shards are just file copies; they hold no open descriptor, so creating
        # them outside the fork mutex is safe.
        worker_count.times { shards << @shard_manager.create_shard }

        pids = readers = nil
        # No pipe writer FD may exist outside this mutex. The scheduler starts
        # coordinators concurrently, so if a sibling step forks while our writer
        # ends are open, its children inherit them and hold our pipes open: `drain`
        # then never sees EOF and the step stays "running" until those foreign
        # children exit. The chunk queue is pipe-based too, so a leaked writer
        # there keeps `claim` from ever returning nil. Creating the pipes and
        # chunk queue, forking, and closing the parent-side writers all under the
        # one mutex keeps every writer FD invisible to a concurrent fork.
        @fork_mutex.synchronize do
          chunk_queue = ChunkQueue.filled(boundaries.size) unless boundaries.empty?
          pipes = Array.new(worker_count) { IO.pipe }
          ForkManager.with_batched_forks do
            pids =
              worker_count.times.map do |index|
                ForkManager.fork do
                  run_in_fork(pipes, index, shards[index], boundaries, chunk_queue)
                end
              end
          end
          chunk_queue&.close # only the workers claim from it now
          pipes.each { |(_reader, writer)| writer.close }
          readers = pipes.map(&:first)
        end

        begin
          @step_handle.with_progress(max_progress: total) do |progress|
            drain(readers, progress, on_worker_done: method(:worker_finished))
          end
        ensure
          readers.each(&:close)
        end

        await(pids)
      end

      def run_inline(shards)
        shard_path = @shard_manager.create_shard
        shards << shard_path

        _boundaries, total = compute_plan
        @step_handle.with_progress(max_progress: total) do |progress|
          StepRunner.new(
            step: @step_factory.call(@step_class),
            shard_path:,
            reporter: InlineProgressSink.new(progress),
          ).run
        end
      end

      # The chunk boundaries and the step's total row count, from one source opened
      # only here. Boundaries are empty for an unpartitioned step (one worker reads
      # the whole source). The workers don't know the total once they start claiming
      # chunks, so the parent counts it up front (`max_progress` with no chunk set
      # counts the whole source).
      def compute_plan
        step = @step_factory.call(@step_class)
        begin
          source = step.source
          boundaries =
            @fork_count > 1 ? source.partition_boundaries(@fork_count * CHUNKS_PER_FORK) : []
          [boundaries, source.max_progress]
        ensure
          step.source.cleanup
        end
      end

      def chunk_for(boundaries, index)
        [boundaries[index], boundaries[index + 1]]
      end

      # A partitioned worker claims chunks off the shared queue; an unpartitioned one
      # falls back to StepRunner's default (the whole source).
      def run_in_fork(pipes, mine, shard_path, boundaries, chunk_queue)
        close_other_pipes(pipes, mine)

        read = chunk_queue ? { chunks: claim_chunks(chunk_queue, boundaries) } : {}
        StepRunner.new(
          step: @step_factory.call(@step_class),
          shard_path:,
          reporter: PipeProgressSink.new(pipes[mine][1]),
          **read,
        ).run
      end

      # A lazy stream of chunks pulled off the shared queue, one each time the worker
      # asks for the next.
      def claim_chunks(chunk_queue, boundaries)
        Enumerator.new do |yielder|
          while (index = chunk_queue.claim)
            yielder << chunk_for(boundaries, index)
          end
        end
      end

      def close_other_pipes(pipes, mine)
        pipes.each_with_index do |(reader, writer), index|
          reader.close
          writer.close unless index == mine
        end
      end

      def await(pids)
        pids.each do |pid|
          _, status = Process.waitpid2(pid)
          next if status.success?

          raise WorkerCrashedError,
                "A worker for #{@step_class.title} exited unexpectedly (#{status}). " \
                  "Check the error output above for the cause."
        end
      end

      # Reads the workers' progress from their pipes into `progress` until they all
      # close. `on_worker_done` runs each time one closes, with the number of
      # workers still running.
      def drain(readers, progress, on_worker_done: nil)
        pending = readers.dup

        until pending.empty?
          ready, = IO.select(pending)
          ready.each do |reader|
            line = reader.gets
            if line.nil?
              pending.delete(reader)
              on_worker_done&.call(pending.size)
              next
            end

            _, increment, warnings, errors = line.split
            progress.update(
              increment_by: increment.to_i,
              warning_count: warnings.to_i,
              error_count: errors.to_i,
            )
          end
        end
      end

      # Runs when a worker finishes: drop the live fork count and give its fork back
      # to the scheduler, so another step can use the free core while the slower
      # workers keep going.
      def worker_finished(still_running)
        @step_handle.report_concurrency(still_running)
        @scheduler.release_forks(@step_class, 1)
      end

      def failure_notice(error)
        "#{error.class}: #{error.message}"
      end
    end
  end
end
