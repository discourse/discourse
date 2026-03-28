# frozen_string_literal: true

module DiscourseWorkflows
  class Form::Submit
    include Service::Base

    params do
      attribute :uuid, :string
      attribute :form_data, default: -> { {} }

      validates :uuid, presence: true
      validate :form_data_must_be_hash

      def form_data_must_be_hash
        errors.add(:form_data, :invalid) unless form_data.is_a?(Hash)
      end
    end

    model :trigger_node
    model :execution, :run_workflow
    model :response_metadata, :compute_response_metadata

    private

    def fetch_trigger_node(params:)
      DiscourseWorkflows::Node.enabled_of_type("trigger:form").find_by(
        "configuration->>'uuid' = ?",
        params.uuid,
      )
    end

    def run_workflow(trigger_node:, params:, guardian:)
      form_data = trigger_node.form_data_from(params.form_data)
      trigger_data = { form_data: form_data, submitted_at: Time.current.utc.iso8601 }
      DiscourseWorkflows::Executor.new(trigger_node, trigger_data, user: guardian.user).run
    end

    def compute_response_metadata(trigger_node:)
      {
        has_downstream_form: trigger_node.downstream_form?,
        response_mode: trigger_node.configuration["response_mode"] || "on_received",
      }
    end
  end
end
