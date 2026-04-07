# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module FormPublishing
      extend ActiveSupport::Concern

      class_methods do
        def form_channel(execution_id)
          token = HmacSigner.sign("form_execution:#{execution_id}")
          "/discourse-workflows/form-execution/#{execution_id}-#{token}"
        end
      end

      private

      def form_triggered?
        @snapshot&.find_node(@trigger_node_id)&.type == "trigger:form"
      end

      def publish_form_completion
        message = {
          status: "success",
          form_completion: @state.context["__form_completion"].presence,
        }.compact
        MessageBus.publish(form_channel(@state.execution.id), message)
      end

      def publish_form_status(status)
        MessageBus.publish(form_channel(@state.execution.id), { status: status })
      end

      def form_channel(execution_id)
        self.class.form_channel(execution_id)
      end
    end
  end
end
