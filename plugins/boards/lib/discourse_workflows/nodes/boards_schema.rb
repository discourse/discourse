# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module BoardsSchema
        CARD_PROPERTIES = JSON.parse(<<~JSON).freeze
          {
            "id": { "type": "integer" },
            "title": { "type": ["string", "null"] },
            "unicode_title": { "type": "string" },
            "board_id": { "type": "integer" },
            "column_id": { "type": "integer" },
            "assigned_to_id": { "type": ["integer", "null"] },
            "topic_id": { "type": ["integer", "null"] },
            "url": { "type": "string" }
          }
        JSON

        BOARD_PROPERTIES = JSON.parse(<<~JSON).freeze
          {
            "id": { "type": "integer" },
            "name": { "type": "string" },
            "url": { "type": "string" }
          }
        JSON

        COLUMN_PROPERTIES = JSON.parse(<<~JSON).freeze
          {
            "id": { "type": "integer" },
            "position": { "type": "integer" },
            "title": { "type": "string" },
            "unicode_title": { "type": "string" },
            "icon": { "type": ["string", "null"] },
            "color": { "type": ["string", "null"] },
            "board_id": { "type": "integer" },
            "move_to_category_id": { "type": ["integer", "null"] },
            "tag_id": { "type": ["integer", "null"] }
          }
        JSON

        CARD_MOVED_PROPERTIES = {
          "old_column" => {
            "type" => %w[object null],
            "properties" => COLUMN_PROPERTIES,
          },
          "new_column" => {
            "type" => "object",
            "properties" => COLUMN_PROPERTIES,
          },
        }.freeze

        CARD_MOVED_SCHEMA =
          DiscourseWorkflows::Schema.entity(
            "card_moved",
            CARD_MOVED_PROPERTIES,
            "Card moved event details",
          )

        CARD_SCHEMA =
          DiscourseWorkflows::Schema.entity(
            "card",
            CARD_PROPERTIES.merge("assignee" => DiscourseWorkflows::Schema::ASSIGNEE_PROPERTIES),
            "Card, with board and column details",
          )

        BOARD_SCHEMA = DiscourseWorkflows::Schema.entity("board", BOARD_PROPERTIES, "Board")

        ACTING_USER_SCHEMA =
          DiscourseWorkflows::Schema.entity(
            "acting_user",
            DiscourseWorkflows::Schema::USER_PROPERTIES,
            "User who moved the card",
          )

        CARD_MOVED_OUTPUT_SCHEMA =
          DiscourseWorkflows::Schema.merge(
            CARD_SCHEMA,
            BOARD_SCHEMA,
            CARD_MOVED_SCHEMA,
            ACTING_USER_SCHEMA,
          )

        CARD_MOVED_V2_OUTPUT_SCHEMA =
          DiscourseWorkflows::Schema.merge(
            CARD_SCHEMA,
            BOARD_SCHEMA,
            CARD_MOVED_SCHEMA,
            DiscourseWorkflows::Schema::ACTOR_SCHEMA,
          )
      end
    end
  end
end
