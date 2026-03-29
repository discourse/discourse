# frozen_string_literal: true

module DiscourseWorkflows
  module WebhookSchema
    HTTP_METHODS = %w[GET POST PUT DELETE PATCH HEAD].freeze

    CONFIGURATION_FIELDS = {
      authentication: {
        type: :options,
        options: %w[none basic_auth],
        default: "none",
        ui: {
          expression: true,
        },
      },
      credential_id: {
        type: :credential,
        credential_type: :basic_auth,
        visible_if: {
          authentication: %w[basic_auth],
        },
      },
      http_method: {
        type: :options,
        required: true,
        default: "GET",
        options: HTTP_METHODS,
        expression: true,
      },
      response_mode: {
        type: :options,
        required: true,
        default: "immediately",
        options: %w[immediately when_last_node_finishes respond_to_webhook],
      },
      response_code: {
        type: :string,
        required: false,
        default: "200",
        visible_if: {
          response_mode: "when_last_node_finishes",
        },
      },
    }.freeze

    OUTPUT_FIELDS = {
      body: :object,
      headers: :object,
      query: :object,
      method: :string,
      webhook_url: :string,
    }.freeze
  end
end
