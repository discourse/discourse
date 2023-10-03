# frozen_string_literal: true

require "monitor"

module WorkQueue
  class WorkQueueFull < StandardError
  end

  class ThreadSafeWrapper
    include MonitorMixin

    def initialize(queue)
      mon_initialize

      @queue = queue
      @has_items = new_cond
    end

    def push(task, force:)
      synchronize do
        previously_empty = @queue.empty?
        @queue.push(task, force: force)

        @has_items.signal if previously_empty
      end
    end

    def shift(block:)
      synchronize do
        loop do
          if task = @queue.shift
            break task
          elsif block
            @has_items.wait
          else
            break nil
          end
        end
      end
    end

    def empty?
      synchronize { @queue.empty? }
    end

    def size
      synchronize { @queue.size }
    end
  end

  class FairQueue
    attr_reader :size

    def initialize(limit, &blk)
      @limit = limit
      @size = 0
      @elements = Hash.new { |h, k| h[k] = blk.call }
    end

    def push(task, force:)
      raise WorkQueueFull if !force && @size >= @limit
      key, task = task.values_at(:key, :task)
      @elements[key].push(task, force: force)
      @size += 1
      nil
    end

    def shift
      unless @elements.empty?
        key, queue = @elements.shift

        task = queue.shift

        @elements[key] = queue unless queue.empty?

        @size -= 1

        { key: key, task: task }
      end
    end

    def empty?
      @elements.empty?
    end
  end

  class BoundedQueue
    def initialize(limit)
      @limit = limit
      @elements = []
    end

    def push(task, force:)
      raise WorkQueueFull if !force && @elements.size >= @limit
      @elements << task
      nil
    end

    def shift
      @elements.shift
    end

    def empty?
      @elements.empty?
    end

    def size
      @elements.size
    end
  end
end
