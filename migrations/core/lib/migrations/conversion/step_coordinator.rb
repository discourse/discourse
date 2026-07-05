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
    # The step is built inside each worker, so the source connection opens there.
    # The parent never holds a source connection; only progress crosses the pipes.
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
        return run_single_worker(shards) if @fork_count == 1
        run_stealing_workers(shards)
      end

      def run_inline(shards)
        shard_path = @shard_manager.create_shard
        shards << shard_path

        StepRunner.new(
          step: @step_factory.call(@step_class),
          shard_path:,
          reporter: InlineProgressSink.new(@step_handle),
          chunk: nil,
        ).run
      end

      # A normal step: one forked worker reads the whole source and reports its
      # own total, which the parent passes on.
      def run_single_worker(shards)
        shard_path = @shard_manager.create_shard
        shards << shard_path
        reader, writer = IO.pipe

        pid = fork_workers(1) { run_in_fork([[reader, writer]], 0, shard_path, nil) }.first
        writer.close

        begin
          @step_handle.with_progress(max_progress: read_max_progress(reader)) do |progress|
            drain([reader], progress)
          end
        ensure
          reader.close
        end

        await([pid])
      end

      # A partitioned step: fork the workers and let them claim chunks from a
      # shared queue until it's empty, each writing to its own shard. The parent
      # knows the total, so the workers only report their progress.
      def run_stealing_workers(shards)
        boundaries, total = compute_partition_plan
        return run_single_worker(shards) if boundaries.empty?

        worker_count = [boundaries.size, @fork_count].min
        # Fewer chunks than forks: hand the forks we won't use back to the budget.
        @scheduler.release_forks(@step_class, @fork_count - worker_count)
        @step_handle.report_concurrency(worker_count)

        queue = ChunkQueue.filled(boundaries.size)
        pipes = Array.new(worker_count) { IO.pipe }
        worker_count.times { shards << @shard_manager.create_shard }

        pids =
          fork_workers(worker_count) do |index|
            run_in_stealing_fork(pipes, index, shards[index], boundaries, queue)
          end

        queue.close # only the workers claim from it now
        pipes.each { |(_reader, writer)| writer.close }
        readers = pipes.map(&:first)

        begin
          @step_handle.with_progress(max_progress: total) do |progress|
            drain(readers, progress, on_worker_done: method(:worker_finished))
          end
        ensure
          readers.each(&:close)
        end

        await(pids)
      end

      # The chunk boundaries and the step's total row count, from one source. With
      # no chunk set, `max_progress` counts the whole source: the total the workers
      # won't report themselves once they start claiming chunks.
      def compute_partition_plan
        step = @step_factory.call(@step_class)
        begin
          source = step.source
          [source.partition_boundaries(@fork_count * CHUNKS_PER_FORK), source.max_progress]
        ensure
          step.source.cleanup
        end
      end

      def fork_workers(count)
        pids = nil
        @fork_mutex.synchronize do
          ForkManager.with_batched_forks do
            pids = count.times.map { |index| ForkManager.fork { yield index } }
          end
        end
        pids
      end

      def chunk_for(boundaries, index)
        [boundaries[index], boundaries[index + 1]]
      end

      def run_in_fork(pipes, mine, shard_path, chunk)
        close_other_pipes(pipes, mine)

        StepRunner.new(
          step: @step_factory.call(@step_class),
          shard_path:,
          reporter: PipeProgressSink.new(pipes[mine][1]),
          chunk:,
        ).run
      end

      def run_in_stealing_fork(pipes, mine, shard_path, boundaries, queue)
        close_other_pipes(pipes, mine)

        claim = -> do
          index = queue.claim
          index && chunk_for(boundaries, index)
        end
        StepRunner.new(
          step: @step_factory.call(@step_class),
          shard_path:,
          reporter: PipeProgressSink.new(pipes[mine][1]),
          chunks: claim,
        ).run
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

      def read_max_progress(reader)
        line = reader.gets
        return if line.nil?

        value = line.split[1]
        value&.to_i
      end

      def failure_notice(error)
        "#{error.class}: #{error.message}"
      end
    end
  end
end
