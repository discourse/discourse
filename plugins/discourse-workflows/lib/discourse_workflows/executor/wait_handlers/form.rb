# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module WaitHandlers
      class Form < Base
        handles_wait_type :form

        def pause!(wait)
          pause_execution!(
            node,
            extra_config: {
              "wait_type" => self.class.wait_type,
              "resume_token" => @state.context["__resume_token"],
              "form_title" => wait.form_title,
              "form_description" => wait.form_description,
              "form_fields" => wait.form_fields,
            },
          )

          MessageBus.publish(
            Executor.form_channel(@state.execution.id),
            { status: "waiting_for_form" },
          )

          @state.execution
        end
      end
    end
  end
end
