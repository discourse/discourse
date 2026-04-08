# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module WaitHandlers
      class Webhook < Base
        handles_wait_type :webhook

        def self.timeout_response_items(execution)
          waiting_input_items(execution)
        end

        def pause!(wait)
          timeout = wait.timeout_seconds

          pause_execution!(
            node,
            waiting_until: timeout&.seconds&.from_now,
            extra_config: {
              "wait_type" => self.class.wait_type,
              "resume_token" => @state.context["__resume_token"],
              "http_method" => wait.http_method,
              "response_mode" => wait.response_mode,
              "response_code" => wait.response_code,
            },
          )

          if timeout
            Jobs.enqueue_in(
              timeout.seconds,
              Jobs::DiscourseWorkflows::ExpireWebhookWait,
              execution_id: @state.execution.id,
            )
          end

          @state.execution
        end
      end
    end
  end
end
