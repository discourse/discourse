# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module WaitHandlers
      class Form < Base
        handles_wait_type :form

        def begin_wait!(wait)
          pause_execution!(
            node,
            extra_config: {
              "wait_type" => self.class.wait_type,
              "resume_token" => @context.resume_token,
              "form_title" => wait.form_title,
              "form_description" => wait.form_description,
              "form_fields" => wait.form_fields,
            },
          )

          MessageBus.publish(Executor.form_channel(execution.id), { status: "waiting_for_form" })

          execution
        end
      end
    end
  end
end
