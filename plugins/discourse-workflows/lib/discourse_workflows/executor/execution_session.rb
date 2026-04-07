# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module ExecutionSession
      RESERVED_CONTEXT_KEYS = %w[
        trigger
        __resume_token
        __form_completion
        _node_contexts
        _execution
        $json
      ].freeze

      def next_step_position
        position = @step_position
        @step_position += 1
        position
      end

      def store_context(key, value)
        if RESERVED_CONTEXT_KEYS.include?(key)
          Rails.logger.warn(
            "discourse-workflows: node name '#{key}' collides with reserved context key " \
              "in workflow #{workflow.id}, context may be corrupted",
          )
        end
        @context[key] = value
      end

      def resolver_context(extra_context = {})
        @context.merge(
          "_node_contexts" => @node_contexts,
          "_execution" => execution_variables,
          **extra_context,
        )
      end

      def node_context_for(node)
        @node_contexts[node.name] ||= {}
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

      def record_step(node_name, step_data)
        @run_data_tracker.record_step(node_name, step_data)
      end

      def mark_wait(node:, step:)
        @waiting_node = node
        @waiting_step = step
      end

      def shared_sandbox
        @shared_sandbox ||=
          DiscourseWorkflows::JsSandbox.new(resolver_context, user: @user, vars: preloaded_vars)
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
