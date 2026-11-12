# frozen_string_literal: true

module DiscourseAi
  module Agents
    class SubagentExecutionState
      # Bound failed or no-progress loops, reserving the last completion for the root answer.
      MAX_COMPLETIONS = 300

      attr_reader :execution_context, :root_token_budget

      def initialize(execution_context:, root_token_budget:, completion_count: 0)
        @execution_context = execution_context
        @root_token_budget = root_token_budget
        @completion_count = completion_count
        execution_context.work_budget ||=
          DiscourseAi::Completions::TurnWorkBudget.new(limit: root_token_budget)
        execution_context.work_execution_state = self
        @mutex = Mutex.new
      end

      def completion_count
        @mutex.synchronize { @completion_count }
      end

      def completion_available?
        @mutex.synchronize { @completion_count < MAX_COMPLETIONS - 1 }
      end

      def reserve_completion
        reserve_completion_with_limit(MAX_COMPLETIONS - 1)
      end

      def reserve_root_final_completion
        reserve_completion_with_limit(MAX_COMPLETIONS)
      end

      def remaining_tokens
        execution_context.work_budget.remaining
      end

      private

      def reserve_completion_with_limit(limit)
        @mutex.synchronize do
          return false if @completion_count >= limit

          @completion_count += 1
          true
        end
      end
    end
  end
end
