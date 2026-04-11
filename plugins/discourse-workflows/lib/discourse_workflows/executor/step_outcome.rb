# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    StepOutcome =
      Data.define(:status, :step, :result, :wait, :error) do
        def self.success(step:, result:)
          new(status: :success, step: step, result: result, wait: nil, error: nil)
        end

        def self.wait(step:, wait:)
          new(status: :wait, step: step, result: nil, wait: wait, error: nil)
        end

        def self.error(step:, error:)
          new(status: :error, step: step, result: nil, wait: nil, error: error)
        end

        def success? = status == :success
        def wait? = status == :wait
        def error? = status == :error
      end
  end
end
