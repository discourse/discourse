# frozen_string_literal: true

module Migrations::Converters
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
      io_from_parent, parent_writer = IO.pipe
      io_from_child, child_writer = IO.pipe

      @worker_pid =
        Process.fork do
          begin
            Process.setproctitle("worker_process#{@index}")

            parent_writer.close
            io_from_child.close

            @item_handler.after_fork

            Oj.load(io_from_parent) do |data|
              stats = @item_handler.handle(data)
              child_writer.write(Oj.dump(stats), "\n")
            end
          rescue SignalException
            exit(1)
          ensure
            @item_handler.close
          end
        end

      child_writer.close
      io_from_parent.close

      @writer = parent_writer
      @reader = io_from_child
    end

    def start_thread
      Thread.new do
        Thread.current.name = "worker_thread#{@index}"

        while (data = @work_queue.pop)
          @writer.write(Oj.dump(data))
          @progress_queue.push(Oj.load(@reader.readline))
        end

        @writer.close
        Process.waitpid(@worker_pid)
        @reader.close
      end
    end
  end
end
