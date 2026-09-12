# frozen_string_literal: true

module Boards
  module Workflows
    module Schema
      CREATE_BOARD_COLUMN_OUTPUT_SCHEMA = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "column_id" => {
            "type" => "integer",
          },
          "title" => {
            "type" => "string",
          },
        },
        "required" => %w[column_id title],
        "additionalProperties" => false,
      }.freeze

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
