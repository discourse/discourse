# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module EventParticipationChanged
        class V1 < DiscourseWorkflows::NodeType
          include PostEventScoping

          description(
            name: "trigger:event_participation_changed",
            version: "1.0",
            defaults: {
              icon: "user-check",
              color: "teal",
            },
            group: "discourse_triggers",
            event: :discourse_calendar_post_event_invitee_status_changed,
            available: -> { SiteSetting.discourse_post_event_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_post_event",
            output_contracts: [
              {
                schema:
                  DiscourseEvents::Events::Workflows::Schema::EVENT_PARTICIPATION_CHANGED_OUTPUT_SCHEMA,
              },
            ],
            properties: PostEventScoping::SCOPE_PROPERTIES,
          )

          def initialize(invitee, *)
            super(parameters: {})
            @invitee = invitee
          end

          # Re-submitting an unchanged RSVP still publishes, so without the
          # `saved_changes?` guard a repeated click would run the workflow again.
          def valid?
            return false if !SiteSetting.discourse_post_event_enabled
            return false if @invitee.blank? || user.blank? || event.blank? || topic.blank?

            @invitee.destroyed? || @invitee.saved_changes?
          end

          def output
            {
              event: event_data(starts_at: event.starts_at, ends_at: event.ends_at),
              post: post_data,
              topic: topic_data(topic),
              user: serialize_user(user),
              participation: {
                status: removed? ? nil : status_name(@invitee.status),
                previous_status: previous_status,
                removed: removed?,
                recurring: !removed? && !!@invitee.recurring,
              },
              stats: stats_data,
            }
          end

          def matches?(trigger_ctx)
            matches_topic_id?(trigger_ctx)
          end

          private

          def event
            return @event if defined?(@event)
            @event = @invitee&.event
          end

          def user
            return @user if defined?(@user)
            @user = @invitee&.user
          end

          def removed?
            !!@invitee&.destroyed?
          end

          def previous_status
            status_name(removed? ? @invitee.status : @invitee.status_before_last_save)
          end

          def status_name(status)
            return nil if status.blank?

            ::DiscourseEvents::Events::Invitee.statuses[status]&.to_s
          end
        end
      end
    end
  end
end
