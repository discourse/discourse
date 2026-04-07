# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionQueue
      def initialize
        @queue = []
      end

      def enqueue(node, items)
        @queue << [node, items]
      end

      def any?
        @queue.any?
      end

      def shift
        @queue.shift
      end

      def clear
        @queue.clear
      end
    end
  end
end
