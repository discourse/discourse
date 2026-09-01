# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module EventEnded
        class V1 < DiscourseWorkflows::NodeType
          include PostEventScoping

          description(
            name: "trigger:event_ended",
            version: "1.0",
            defaults: {
              icon: "calendar-days",
              color: "purple",
            },
            group: "discourse_triggers",
            event: :discourse_post_event_event_ended,
            available: -> { SiteSetting.discourse_post_event_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_post_event",
            output_contracts: [
              { schema: DiscourseEvents::Events::Workflows::Schema::EVENT_ENDED_OUTPUT_SCHEMA },
            ],
            properties: PostEventScoping::SCOPE_PROPERTIES,
          )

          def initialize(event, event_date = nil, *)
            super(parameters: {})
            @event = event
            @event_date = event_date
          end

          # The occurrence is required rather than derived: the next one is
          # scheduled immediately after this fires, so anything read from the
          # event afterwards describes the wrong dates.
          def valid?
            SiteSetting.discourse_post_event_enabled && @event.present? && @event_date.present? &&
              topic.present?
          end

          def output
            {
              event: event_data(starts_at: @event_date.starts_at, ends_at: @event_date.ends_at),
              post: post_data,
              topic: topic_data(topic),
              stats: stats_data,
            }
          end

          def matches?(trigger_ctx)
            matches_topic_id?(trigger_ctx)
          end

          private

          attr_reader :event
        end
      end
    end
  end
end
