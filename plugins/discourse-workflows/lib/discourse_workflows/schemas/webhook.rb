# frozen_string_literal: true

module DiscourseWorkflows
  module Schemas::Webhook
    HTTP_METHODS = %w[GET POST PUT DELETE PATCH HEAD].freeze

    RESPONSE_MODE_ON_RECEIVED = "on_received"
    RESPONSE_MODE_LAST_NODE = "last_node"
    RESPONSE_MODE_RESPONSE_NODE = "response_node"
    RESPONSE_MODES = [
      RESPONSE_MODE_ON_RECEIVED,
      RESPONSE_MODE_LAST_NODE,
      RESPONSE_MODE_RESPONSE_NODE,
    ].freeze

    RESPONSE_DATA_FIRST_ENTRY_JSON = "first_entry_json"
    RESPONSE_DATA_ALL_ENTRIES = "all_entries"
    RESPONSE_DATA_NO_DATA = "no_data"
    RESPONSE_DATA_MODES = [
      RESPONSE_DATA_FIRST_ENTRY_JSON,
      RESPONSE_DATA_ALL_ENTRIES,
      RESPONSE_DATA_NO_DATA,
    ].freeze

    AUTH_MODES = %w[none basic_auth bearer_auth header_auth].freeze

    CONFIGURATION_FIELDS = {
      authentication: {
        type: :options,
        options: AUTH_MODES,
        default: "none",
        no_data_expression: true,
      },
      http_method: {
        type: :options,
        required: true,
        default: "GET",
        options: HTTP_METHODS,
        ui: {
          expression: true,
        },
      },
      response_mode: {
        type: :options,
        required: true,
        default: RESPONSE_MODE_ON_RECEIVED,
        options: RESPONSE_MODES,
      },
      response_code: {
        type: :string,
        required: false,
        default: "200",
        display_options: {
          show: {
            response_mode: [RESPONSE_MODE_ON_RECEIVED, RESPONSE_MODE_LAST_NODE],
          },
        },
      },
      response_data: {
        type: :options,
        required: false,
        default: RESPONSE_DATA_FIRST_ENTRY_JSON,
        options: RESPONSE_DATA_MODES,
        display_options: {
          show: {
            response_mode: [RESPONSE_MODE_LAST_NODE],
          },
        },
      },
      response_body: {
        type: :string,
        required: false,
        display_options: {
          show: {
            response_mode: [RESPONSE_MODE_ON_RECEIVED],
          },
        },
        ui: {
          control: :textarea,
        },
      },
      no_response_body: {
        type: :boolean,
        required: false,
        default: false,
        display_options: {
          show: {
            response_mode: [RESPONSE_MODE_ON_RECEIVED],
          },
        },
      },
      response_headers: {
        type: :fixed_collection,
        type_options: {
          multiple_values: true,
        },
        options: [
          {
            name: "values",
            values: {
              key: {
                type: :string,
                required: true,
              },
              value: {
                type: :string,
                required: true,
              },
            },
          },
        ],
      },
      ip_allowlist: {
        type: :string,
        required: false,
      },
      ignore_bots: {
        type: :boolean,
        required: false,
        default: false,
      },
    }.freeze

    WEBHOOK_SUFFIX_FIELD = { type: :string, required: false }.freeze
  end
end
