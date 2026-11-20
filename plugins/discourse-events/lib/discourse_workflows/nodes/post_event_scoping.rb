# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module PostEventScoping
        # Shared locale scope so every node using these properties resolves
        # `topic_id`/`topic_id_description` from one translated pair.
        I18N_SCOPE = "post_event"

        MAX_GOING_USERNAMES = 100

        SCOPE_PROPERTIES = {
          topic_id: {
            type: :string,
            required: false,
            no_data_expression: true,
          },
        }.freeze

        private

        def topic
          return @topic if defined?(@topic)
          @topic = event&.post&.topic
        end

        def matches_topic_id?(trigger_ctx)
          topic_id = trigger_ctx.get_node_parameter("topic_id").to_s.strip.presence
          topic_id.blank? || topic_id.to_i == topic&.id
        end

        def serialize_event(starts_at:, ends_at:)
          {
            id: event.id,
            name: event.name,
            description: event.description,
            location: event.location,
            url: event.url,
            timezone: event.timezone,
            all_day: !!event.all_day,
            closed: !!event.closed,
            chat_channel_id: event.chat_channel_id,
            recurring: event.recurring?,
            recurrence: event.recurrence,
            starts_at: starts_at&.iso8601,
            ends_at: ends_at&.iso8601,
            custom_fields: event.custom_fields || {},
            going_usernames: going_usernames,
          }
        end

        def serialize_event_post
          post = event&.post
          return nil if post.blank?

          {
            id: post.id,
            post_number: post.post_number,
            url: post.url,
            username: post.user&.username,
          }
        end

        def going_usernames
          event
            .invitees
            .with_status(:going)
            .order(:created_at)
            .limit(MAX_GOING_USERNAMES)
            .pluck("users.username")
        end

        def serialize_event_stats
          serialize_record(event, ::DiscourseEvents::Events::EventStatsSerializer)
        end
      end
    end
  end
end
