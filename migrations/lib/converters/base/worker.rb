# frozen_string_literal: true

module Migrations::Converters::Base
  class Worker
    def initialize(index, input_queue, output_queue, job)
      @index = index
      @input_queue = input_queue
      @output_queue = output_queue
      @job = job

      @threads = []
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
      Migrations::ForkManager.fork do
        begin
          Process.setproctitle("worker_process#{@index}")

          parent_output_stream.close
          fork_input_stream.close

          Oj.load(parent_input_stream) do |data|
            @job.run(data)
            fork_output_stream.write(Oj.dump(stats))
          end
        rescue SignalException
          exit(1)
        end
      end
    end

    def start_input_thread(output_stream, worker_pid)
      @threads << Thread.new do
        Thread.current.name = "worker_#{@index}_input"

        begin
          while (data = @input_queue.pop)
            output_stream.write(Oj.dump(data))
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
          Oj.load(input_stream) { |data| @output_queue.push(data) }
        ensure
          input_stream.close
        end
      end
    end
  end
end
