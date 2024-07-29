# frozen_string_literal: true

WORKER_COUNT = Etc.nprocessors
MIN_PARALLEL_ITEMS = WORKER_COUNT * 10
MAX_QUEUE_SIZE = WORKER_COUNT * 10

private

def execute_parallel
  progress_queue = Queue.new
  progress_thread =
    Thread.new do
      Thread.current.name = "progress_thread"
      with_progressbar do |progressbar|
        while (stats = progress_queue.pop)
          update_progressbar(progressbar, stats)
        end
      end
    end

  Process.warmup
  # GC.start # a little bit of cleanup before we start forking

  # @step.output_db.close

  work_queue = SizedQueue.new(MAX_QUEUE_SIZE)
  workers_threads = []
  worker_output_db_paths = []

  WORKER_COUNT.times do |index|
    db_path = File.join(Convert.output_tmp_dir, "worker_#{index}.db")
    item_handler = ItemHandler.new(@step, db_path)
    OutputDatabase.migrate(path: db_path)
    worker_output_db_paths << db_path

    workers_threads << Worker.new(index, work_queue, item_handler, progress_queue).start
  end

  @step.items.each { |item| work_queue.push(item) }
  work_queue.close

  @step.output_db.reconnect

  workers_threads.each(&:join)
  progress_queue.close
  progress_thread.join

  merge_output_dbs(worker_output_db_paths)
end

def execute_serially
  item_handler = ItemHandler.new(@step)

  with_progressbar do |progressbar|
    @step.items.each do |item|
      stats = item_handler.handle(item)
      update_progressbar(progressbar, stats)
    end
  end
end

def merge_output_dbs(worker_output_db_paths)
  print "    Merging output databases...\r"
  start_time = Time.now

  @step.output_db.copy_from(worker_output_db_paths)
  worker_output_db_paths.each { |path| OutputDatabase.reset!(path: path) }

  puts "    Merging output databases: #{DateHelper.human_readable_time(Time.now - start_time)}"
end
