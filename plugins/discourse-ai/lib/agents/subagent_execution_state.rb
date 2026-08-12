# frozen_string_literal: true

module DiscourseAi
  module Agents
    class SubagentExecutionState
      MAX_SPAWN_CALLS = 5
      MAX_COMPLETIONS = 100

      attr_reader :execution_context, :root_token_budget

      def initialize(execution_context:, root_token_budget:)
        @execution_context = execution_context
        @root_token_budget = root_token_budget
        @spawn_count = 0
        @completion_count = 0
        @mutex = Mutex.new
      end

      def spawn_available?
        @mutex.synchronize { @spawn_count < MAX_SPAWN_CALLS }
      end

      def reserve_spawn
        @mutex.synchronize do
          return false if @spawn_count >= MAX_SPAWN_CALLS

          @spawn_count += 1
          true
        end
      end

      def completion_available?
        @mutex.synchronize { @completion_count < MAX_COMPLETIONS - 1 }
      end

      def reserve_completion(final: false)
        @mutex.synchronize do
          limit = final ? MAX_COMPLETIONS : MAX_COMPLETIONS - 1
          return false if @completion_count >= limit

          @completion_count += 1
          true
        end
      end

      def remaining_tokens
        [root_token_budget - execution_context.token_usage_tracker.total, 0].max
      end
    end
  end
end
