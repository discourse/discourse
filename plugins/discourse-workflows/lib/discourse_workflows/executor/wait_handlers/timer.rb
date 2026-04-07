# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module WaitHandlers
      class Timer < Base
        handles_wait_type :timer

        def self.timeout_response_items(execution)
          waiting_input_items(execution)
        end

        def pause!(wait)
          duration = wait.wait_duration_seconds.seconds

          pause_execution!(
            node,
            waiting_until: duration.from_now,
            extra_config: {
              "wait_type" => self.class.wait_type,
              "wait_amount" => wait.wait_amount,
              "wait_unit" => wait.wait_unit,
            },
          )

          Jobs.enqueue_in(
            duration,
            Jobs::DiscourseWorkflows::ResumeTimer,
            execution_id: @state.execution.id,
          )

          @state.execution
        end
      end
    end
  end
end
