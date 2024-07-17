# frozen_string_literal: true

module Migrations::Converters::Base
  class Worker
    def initialize(index, work_queue, item_handler, progress_queue)
      @index = index
      @work_queue = work_queue
      @item_handler = item_handler
      @progress_queue = progress_queue
    end

    def start
      start_fork
      start_thread
    end

    private

    def start_fork
      parent_reader, parent_writer = IO.pipe
      child_reader, child_writer = IO.pipe

      @worker_pid =
        Migrations::ForkManager.instance.fork do
          begin
            Process.setproctitle("worker_process#{@index}")

            parent_writer.close
            child_reader.close

            @item_handler.after_fork

            Oj.load(parent_reader) do |data|
              stats = @item_handler.handle(data)
              child_writer.write(Oj.dump(stats), "\n")
            end
          rescue SignalException
            warn "Worker process #{@index} terminated by signal: #{e.message}"
            exit(1)
          ensure
            @item_handler.close
          end
        end

      child_writer.close
      parent_reader.close

      @writer = parent_writer
      @reader = child_reader
    end

    def start_thread
      Thread.new do
        Thread.current.name = "worker_thread#{@index}"

        begin
          while (data = @work_queue.pop)
            @writer.write(Oj.dump(data))
            @progress_queue.push(Oj.load(@reader.readline))
          end
        rescue => e
          warn "Worker thread #{@index} encountered an error: #{e.message}"
        ensure
          @writer.close
          Process.waitpid(@worker_pid) if @worker_pid
          @reader.close
        end
      end
    end
  end
end
