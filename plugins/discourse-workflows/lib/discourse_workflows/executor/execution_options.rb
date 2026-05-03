# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    ExecutionOptions =
      Data.define(:user, :execution_mode, :error_depth, :workflow_execution_chain) do
        def initialize(
          user: nil,
          execution_mode: :normal,
          error_depth: 0,
          workflow_execution_chain: []
        )
          super
        end
      end
  end
end
