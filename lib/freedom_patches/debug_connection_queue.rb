# frozen_string_literal: true

if ENV["DEBUG_AR_CONNECTION_QUEUE"] == "1"
  module QueuePatch
    # Add +element+ to the queue.  Never blocks.
    def add(element)
      puts "::group::##{Process.pid} Adding element to the queue"
      puts Thread.current.backtrace.first(30).join("\n")
      puts "::endgroup::"
      super
    end

    # If +element+ is in the queue, remove and return it, or +nil+.
    def delete(element)
      puts "::group::##{Process.pid} Delete element from the queue"
      puts Thread.current.backtrace.first(30).join("\n")
      puts "::endgroup::"
      super
    end

    # Remove all elements from the queue.
    def clear
      puts "::group::##{Process.pid} Clear all elements from the queue"
      puts Thread.current.backtrace.first(30).join("\n")
      puts "::endgroup::"
      super
    end

    private

    def remove
      puts "::group::##{Process.pid} Removing element from the queue"
      puts Thread.current.backtrace.first(30).join("\n")
      puts "::endgroup::"
      super
    end
  end

  ActiveRecord::ConnectionAdapters::ConnectionPool::Queue.prepend(QueuePatch)
end
