# frozen_string_literal: true

module Migrations
  module Conversion
    # Runs one step end to end on its own thread for the {StepScheduler}. It forks
    # the step's workers — one for a normal step, several for a partitioned one (or
    # none under `--no-fork`, where the single worker runs inline). Each worker
    # builds the step itself, opens its own source, reads its slice of the rows,
    # and writes them to its own shard.
    #
    # The coordinator relays the workers' combined progress to the reporter. Once
    # they all exit cleanly it hands the finished shards to the {Consolidator},
    # which merges them into the run database on a background thread, so the step
    # finishes without waiting for its own merge.
    #
    # The step is built inside each worker, not here, so its source connection is
    # opened there. The parent never holds a source connection, and nothing but
    # progress crosses the pipes.
    class StepCoordinator
      class WorkerCrashedError < StandardError
      end

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
        @step_handle.report_concurrency(@fork_count)
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

        boundaries = compute_boundaries
        worker_count = boundaries.nil? ? 1 : [boundaries.size, 1].max

        pipes = Array.new(worker_count) { IO.pipe }
        worker_count.times { shards << @shard_manager.create_shard }

        pids = nil
        @fork_mutex.synchronize do
          ForkManager.with_batched_forks do
            pids =
              worker_count.times.map do |index|
                chunk = chunk_for(boundaries, index)
                ForkManager.fork { run_in_fork(pipes, index, shards[index], chunk) }
              end
          end
        end

        pipes.each { |(_reader, writer)| writer.close }
        readers = pipes.map(&:first)

        begin
          consume_progress(readers)
        ensure
          readers.each(&:close)
        end

        await(pids)
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

      def compute_boundaries
        return nil if @fork_count == 1

        step = @step_factory.call(@step_class)
        begin
          step.source.partition_boundaries(@fork_count)
        ensure
          step.source.cleanup
        end
      end

      def chunk_for(boundaries, index)
        return nil if boundaries.nil? || boundaries.empty?
        [boundaries[index], boundaries[index + 1]]
      end

      def run_in_fork(pipes, mine, shard_path, chunk)
        pipes.each_with_index do |(reader, writer), index|
          reader.close
          writer.close unless index == mine
        end

        step = @step_factory.call(@step_class)
        StepRunner.new(
          step:,
          shard_path:,
          reporter: PipeProgressSink.new(pipes[mine][1]),
          chunk:,
        ).run
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

      def consume_progress(readers)
        @step_handle.with_progress(max_progress: total_max_progress(readers)) do |progress|
          drain_progress(readers, progress)
        end
      end

      def total_max_progress(readers)
        maxes = readers.map { |reader| read_max_progress(reader) }
        return if maxes.any?(&:nil?)
        maxes.sum
      end

      def drain_progress(readers, progress)
        pending = readers.dup

        until pending.empty?
          ready, = IO.select(pending)
          ready.each do |reader|
            line = reader.gets
            if line.nil?
              pending.delete(reader)
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
