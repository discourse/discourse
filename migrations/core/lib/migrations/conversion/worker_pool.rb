# frozen_string_literal: true

require "etc"

module Migrations
  module Conversion
    # Owns worker sizing and the fork machinery for a conversion run. It knows
    # nothing about steps, progress reporting, or scheduling — callers bring
    # the queues and a job factory, the pool brings the processes.
    class WorkerPool
      DEFAULT_SIZE = Etc.nprocessors - 1 # leave 1 CPU free to do other work

      attr_reader :size

      def initialize(size: DEFAULT_SIZE)
        @size = size
      end

      # Forks worker processes (default: all `size` of them), each running the
      # job built by `job_factory`. The factory is called once per worker, so
      # workers never share job state. Workers exit when `work_queue` is
      # closed and drained. Returns a handle for the started batch.
      def start(work_queue:, output_queue:, size: @size, &job_factory)
        worker_count = size.clamp(1, @size)
        Process.warmup

        workers = []
        ForkManager.batch_forks do
          worker_count.times do |index|
            workers << Worker.new(index, work_queue, output_queue, job_factory.call).start
          end
        end

        Batch.new(workers)
      end

      class Batch
        def initialize(workers)
          @workers = workers
        end

        def wait
          @workers.each(&:wait)
        end
      end
    end
  end
end
