# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    StepOutcome =
      Data.define(:status, :step, :result, :error) do
        def self.success(step:, result:)
          new(status: :success, step: step, result: result, error: nil)
        end

        def self.wait(step:, error:)
          new(status: :wait, step: step, result: nil, error: error)
        end

        def self.error(step:, error:)
          new(status: :error, step: step, result: nil, error: error)
        end

        def success? = status == :success
        def wait? = status == :wait
        def error? = status == :error
      end
  end
end
