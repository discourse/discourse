# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    ExecutionOptions =
      Data.define(:user, :execution_mode, :error_depth) do
        def initialize(user: nil, execution_mode: :normal, error_depth: 0)
          super
        end
      end
  end
end
