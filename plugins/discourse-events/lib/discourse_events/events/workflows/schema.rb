# frozen_string_literal: true

module DiscourseEvents
  module Events
    module Workflows
      module Schema
        EVENT_PROPERTIES = JSON.parse(<<~JSON).freeze
        {
          "id": { "type": "integer" },
          "name": { "type": ["string", "null"] },
          "description": { "type": ["string", "null"] },
          "location": { "type": ["string", "null"] },
          "url": { "type": ["string", "null"] },
          "timezone": { "type": ["string", "null"] },
          "all_day": { "type": "boolean" },
          "closed": { "type": "boolean" },
          "recurring": { "type": "boolean" },
          "recurrence": { "type": ["string", "null"] },
          "starts_at": { "type": ["string", "null"], "format": "date-time" },
          "ends_at": { "type": ["string", "null"], "format": "date-time" },
          "custom_fields": { "type": "object" }
        }
      JSON

        POST_PROPERTIES = JSON.parse(<<~JSON).freeze
        {
          "id": { "type": "integer" },
          "post_number": { "type": "integer" },
          "url": { "type": ["string", "null"] }
        }
      JSON

        STATS_PROPERTIES = JSON.parse(<<~JSON).freeze
        {
          "going": { "type": "integer" },
          "going_recurring": { "type": "integer" },
          "interested": { "type": "integer" },
          "not_going": { "type": "integer" },
          "invited": { "type": "integer" },
          "capacity": { "type": ["integer", "null"] }
        }
      JSON

        PARTICIPATION_PROPERTIES = JSON.parse(<<~JSON).freeze
        {
          "status": { "type": ["string", "null"], "enum": ["going", "interested", "not_going", null] },
          "previous_status": { "type": ["string", "null"], "enum": ["going", "interested", "not_going", null] },
          "removed": { "type": "boolean" },
          "recurring": { "type": "boolean" }
        }
      JSON

        POST_SCHEMA =
          DiscourseWorkflows::Schema.entity(
            "post",
            POST_PROPERTIES,
            "Post the event is attached to",
          )

        # `going` counts RSVPs, not verified attendance, and every count excludes
        # suspended, silenced and staged users.
        STATS_SCHEMA =
          DiscourseWorkflows::Schema.entity(
            "stats",
            STATS_PROPERTIES,
            "RSVP counts when the workflow was triggered",
          )

        PARTICIPATION_SCHEMA =
          DiscourseWorkflows::Schema.entity(
            "participation",
            PARTICIPATION_PROPERTIES,
            "RSVP that changed. `status` is null and `removed` is true when the user withdrew",
          )

        # `starts_at`/`ends_at` name a single occurrence, and which one differs per
        # trigger, so each gets its own description rather than a shared constant.
        ENDED_EVENT_SCHEMA =
          DiscourseWorkflows::Schema.entity(
            "event",
            EVENT_PROPERTIES,
            "Event, with the dates of the occurrence that just ended",
          )

        CURRENT_EVENT_SCHEMA =
          DiscourseWorkflows::Schema.entity(
            "event",
            EVENT_PROPERTIES,
            "Event, with the dates of its current occurrence",
          )

        EVENT_ENDED_OUTPUT_SCHEMA =
          DiscourseWorkflows::Schema.merge(
            ENDED_EVENT_SCHEMA,
            POST_SCHEMA,
            DiscourseWorkflows::Schema::TOPIC_LIST_ITEM_SCHEMA,
            STATS_SCHEMA,
          ).freeze

        EVENT_PARTICIPATION_CHANGED_OUTPUT_SCHEMA =
          DiscourseWorkflows::Schema.merge(
            CURRENT_EVENT_SCHEMA,
            POST_SCHEMA,
            DiscourseWorkflows::Schema::TOPIC_LIST_ITEM_SCHEMA,
            DiscourseWorkflows::Schema::USER_SCHEMA,
            PARTICIPATION_SCHEMA,
            STATS_SCHEMA,
          ).freeze
      end
    end
  end
end
