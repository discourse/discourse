# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module WaitHandlers
      class Webhook < Base
        handles_wait_type :webhook

        def pause!(wait)
          pause_execution!(
            node,
            extra_config: {
              "wait_type" => self.class.wait_type,
              "resume_token" => @state.context["__resume_token"],
              "http_method" => wait.http_method,
              "response_mode" => wait.response_mode,
              "response_code" => wait.response_code,
            },
          )

          @state.execution
        end
      end
    end
  end
end
