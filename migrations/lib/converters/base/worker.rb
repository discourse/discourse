# frozen_string_literal: true

require "oj"

module Migrations::Converters::Base
  class Worker
    def initialize(index, input_queue, output_queue, job)
      @index = index
      @input_queue = input_queue
      @output_queue = output_queue
      @job = job

      @threads = []
      @mutex = Mutex.new
      @data_processed = ConditionVariable.new
    end

    def start
      parent_input_stream, parent_output_stream = IO.pipe
      fork_input_stream, fork_output_stream = IO.pipe

      worker_pid =
        start_fork(parent_input_stream, parent_output_stream, fork_input_stream, fork_output_stream)

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

    def start_fork(parent_input_stream, parent_output_stream, fork_input_stream, fork_output_stream)
      Migrations::ForkManager.instance.fork do
        begin
          Process.setproctitle("worker_process#{@index}")

          parent_output_stream.close
          fork_input_stream.close

          Oj.load(parent_input_stream) do |data|
            result = @job.run(data)
            # result = @job.run(data[:data])
            Oj.to_stream(fork_output_stream, result)
          end
        rescue SignalException
          exit(1)
        ensure
          @job.cleanup
        end
      end
    end

    def start_input_thread(output_stream, worker_pid)
      @threads << Thread.new do
        Thread.current.name = "worker_#{@index}_input"

        begin
          while (data = @input_queue.pop)
            Oj.to_stream(output_stream, data)
            # Oj.to_stream(output_stream, { data: })
            @mutex.synchronize { @data_processed.wait(@mutex) }
          end
        ensure
          output_stream.close
          Process.waitpid(worker_pid)
        end
      end
    end

    def start_output_thread(input_stream)
      @threads << Thread.new do
        Thread.current.name = "worker_#{@index}_output"

        begin
          Oj.load(input_stream) do |data|
            @output_queue.push(data)
            @mutex.synchronize { @data_processed.signal }
          end
        ensure
          input_stream.close
        end
      end
    end
  end
end
