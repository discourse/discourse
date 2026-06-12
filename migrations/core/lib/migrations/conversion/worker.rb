# frozen_string_literal: true

require "oj"

module Migrations
  module Conversion
    class Worker
      class CrashedError < StandardError
      end

      OJ_SETTINGS = { mode: :object, class_cache: true, symbol_keys: true }

      def initialize(index, input_queue, output_queue, job)
        @index = index
        @input_queue = input_queue
        @output_queue = output_queue
        @job = job

        @threads = []
        @mutex = Mutex.new
        @data_processed = ConditionVariable.new
        @sent_count = 0
        @processed_count = 0
        @output_closed = false
      end

      def start
        parent_input_stream, parent_output_stream = IO.pipe
        fork_input_stream, fork_output_stream = IO.pipe

        worker_pid =
          start_fork(
            parent_input_stream,
            parent_output_stream,
            fork_input_stream,
            fork_output_stream,
          )

        fork_output_stream.close
        parent_input_stream.close

        start_input_thread(parent_output_stream, worker_pid)
        start_output_thread(fork_input_stream)

        self
      end

      def wait
        @threads.each(&:join)
      end

      private

      def start_fork(
        parent_input_stream,
        parent_output_stream,
        fork_input_stream,
        fork_output_stream
      )
        ForkManager.fork do
          Process.setproctitle("worker_process#{@index}")

          parent_output_stream.close
          fork_input_stream.close

          @job.setup

          Oj.load(parent_input_stream, OJ_SETTINGS) do |data|
            result = @job.run(data)
            Oj.to_stream(fork_output_stream, result, OJ_SETTINGS)
          end
        rescue SignalException
          exit(1)
        ensure
          @job.cleanup
        end
      end

      def start_input_thread(output_stream, worker_pid)
        @threads << Thread.new do
          Thread.current.name = "worker_#{@index}_input"
          # A `CrashedError` surfaces through `Worker#wait` (`Thread#join`);
          # without this, an interrupted run would additionally report the
          # error for every worker.
          Thread.current.report_on_exception = false

          begin
            while (data = @input_queue.pop)
              Oj.to_stream(output_stream, data, OJ_SETTINGS)
              @sent_count += 1

              # waiting on the condition variable alone would lose the wakeup
              # when the result arrives before this thread reaches `wait`, so
              # the counters act as the wait predicate
              @mutex.synchronize do
                @data_processed.wait(@mutex) while @processed_count < @sent_count && !@output_closed
              end
            end
          rescue Errno::EPIPE
            # The worker process died; the status check below raises the error.
          ensure
            output_stream.close
            _, status = Process.waitpid2(worker_pid)

            if !status.success?
              raise CrashedError,
                    "Worker process #{@index} exited unexpectedly (#{status}). " \
                      "Check the error output above for the cause."
            end
          end
        end
      end

      def start_output_thread(input_stream)
        @threads << Thread.new do
          Thread.current.name = "worker_#{@index}_output"

          begin
            Oj.load(input_stream, OJ_SETTINGS) do |data|
              @output_queue.push(data)

              @mutex.synchronize do
                @processed_count += 1
                @data_processed.signal
              end
            end
          ensure
            input_stream.close

            @mutex.synchronize do
              @output_closed = true
              @data_processed.signal
            end
          end
        end
      end
    end
  end
end
