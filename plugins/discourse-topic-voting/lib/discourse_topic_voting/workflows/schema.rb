# frozen_string_literal: true

module DiscourseTopicVoting
  module Workflows
    module Schema
      VOTE_SCHEMA =
        DiscourseWorkflows::Schema.entity(
          "vote",
          JSON.parse(<<~JSON),
          {
            "id": { "type": "integer" },
            "count": { "type": "integer" },
            "created_at": { "type": "string", "format": "date-time" }
          }
        JSON
          "Vote that was cast, with the topic vote count once it was cast",
        )

      TOPIC_RECEIVED_VOTE_OUTPUT_SCHEMA =
        DiscourseWorkflows::Schema.merge(
          DiscourseWorkflows::Schema::TOPIC_LIST_ITEM_SCHEMA,
          DiscourseWorkflows::Schema::USER_SCHEMA,
          VOTE_SCHEMA,
        ).freeze
    end
  end
end
