# frozen_string_literal: true

module Boards
  module Workflows
    module Schema
      CREATE_BOARD_OUTPUT_SCHEMA = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "board_id" => {
            "type" => "integer",
          },
          "slug" => {
            "type" => "string",
          },
        },
        "required" => %w[board_id slug],
        "additionalProperties" => false,
      }.freeze
    end
  end
end
