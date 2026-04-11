# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    ExecutionOutcome =
      Data.define(:status, :wait) do
        def self.complete
          new(status: :complete, wait: nil)
        end

        def self.wait(wait:)
          new(status: :wait, wait: wait)
        end

        def complete? = status == :complete
        def wait? = status == :wait
      end
  end
end
