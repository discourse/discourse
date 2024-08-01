# frozen_string_literal: true

WORKER_COUNT = Etc.nprocessors
MIN_PARALLEL_ITEMS = WORKER_COUNT * 10
MAX_QUEUE_SIZE = WORKER_COUNT * 10

private

def execute_parallel
  # GC.start # a little bit of cleanup before we start forking

  # @step.output_db.close
end
