# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionRuntime
      attr_reader :waiting_node, :waiting_step

      def initialize(context:, user:)
        @context = context
        @user = user
        reset!
      end

      def reset!
        dispose_shared_sandbox
        @queue = ExecutionQueue.new
        clear_wait
      end

      def enqueue(node, items)
        @queue.enqueue(node, items)
      end

      def shift_queue
        @queue.shift
      end

      def queued?
        @queue.any?
      end

      def mark_wait(node:, step:)
        @waiting_node = node
        @waiting_step = step
      end

      def clear_wait
        @waiting_node = nil
        @waiting_step = nil
      end

      def shared_sandbox
        @shared_sandbox ||=
          DiscourseWorkflows::JsSandbox.new(
            @context.resolver_context,
            user: @user,
            vars: preloaded_vars,
          )
      end

      def dispose_shared_sandbox
        @shared_sandbox&.dispose
        @shared_sandbox = nil
      end

      def preloaded_vars
        @preloaded_vars ||= DiscourseWorkflows::Variable.pluck(:key, :value).to_h
      end
    end
  end
end
