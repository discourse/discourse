# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module RejectSubmission
      class V1 < NodeType
        description(
          name: "action:reject_submission",
          version: "1.0",
          defaults: {
            icon: "triangle-exclamation",
            color: "red",
          },
          outputs: [],
          i18n_scope: "submission_check",
          properties: {
            message: {
              type: :string,
              required: true,
              no_data_expression: true,
            },
          },
        )
      end
    end
  end
end
