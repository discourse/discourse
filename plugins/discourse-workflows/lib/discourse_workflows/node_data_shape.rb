# frozen_string_literal: true

module DiscourseWorkflows
  module NodeDataShape
    NODE_DIRECT_SETTING_KEYS = {
      "notes" => :notes,
      "notesInFlow" => :notes_in_flow,
      "alwaysOutputData" => :always_output_data,
      "onError" => :on_error,
      "continueOnFail" => :continue_on_fail,
    }.freeze

    FORM_TRIGGER_TYPE = "trigger:form"
    FORM_TRIGGER_WEBHOOK_ID_KEY = "webhookId"

    module_function

    def form_trigger?(node_type)
      node_type == FORM_TRIGGER_TYPE ||
        (node_type.respond_to?(:identifier) && node_type.identifier == FORM_TRIGGER_TYPE)
    end
  end
end
