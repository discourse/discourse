# frozen_string_literal: true

module DiscoursePostEvent
  class EventSerializer < ApplicationSerializer
    attributes :can_act_on_discourse_post_event
    attributes :can_update_attendance
    attributes :category_id
    attributes :creator
    attributes :custom_fields
    attributes :ends_at
    attributes :id
    attributes :is_closed
    attributes :is_expired
    attributes :is_ongoing
    attributes :is_private
    attributes :is_public
    attributes :is_standalone
    attributes :minimal
    attributes :name
    attributes :post
    attributes :raw_invitees
    attributes :recurrence
    attributes :recurrence_rule
    attributes :recurrence_until
    attributes :reminders
    attributes :sample_invitees
    attributes :should_display_invitees
    attributes :starts_at
    attributes :stats
    attributes :status
    attributes :timezone
    attributes :show_local_time
    attributes :url
    attributes :description
    attributes :location
    attributes :watching_invitee
    attributes :chat_enabled
    attributes :channel

    def channel
      ::Chat::ChannelSerializer.new(object.chat_channel, root: false, scope:)
    end

    def include_channel?
      object.chat_enabled && defined?(::Chat::ChannelSerializer) && object.chat_channel.present?
    end

    def can_act_on_discourse_post_event
      scope.can_act_on_discourse_post_event?(object)
    end

    def reminders
      (object.reminders || "")
        .split(",")
        .map do |reminder|
          unit, value, type = reminder.split(".").reverse
          type ||= "notification"

          value = value.to_i
          { value: value.to_i.abs, unit: unit, period: value > 0 ? "before" : "after", type: type }
        end
    end

    def is_expired
      object.expired?
    end

    def is_ongoing
      object.ongoing?
    end

    def is_public
      object.public?
    end

    def is_private
      object.private?
    end

    def is_standalone
      object.standalone?
    end

    def is_closed
      object.closed
    end

    def status
      Event.statuses[object.status]
    end

    # lightweight post object containing
    # only needed info for client
    def post
      {
        id: object.post.id,
        post_number: object.post.post_number,
        url: object.post.url,
        topic: {
          id: object.post.topic.id,
          title: object.post.topic.title,
        },
      }
    end

    def can_update_attendance
      scope.current_user && object.can_user_update_attendance(scope.current_user)
    end

    def creator
      BasicUserSerializer.new(object.post.user, embed: :objects, root: false)
    end

    def stats
      EventStatsSerializer.new(object, root: false).as_json
    end

    def watching_invitee
      if scope.current_user
        watching_invitee = Invitee.find_by(user_id: scope.current_user.id, post_id: object.id)
      end

      InviteeSerializer.new(watching_invitee, root: false) if watching_invitee
    end

    def sample_invitees
      invitees = object.most_likely_going
      ActiveModel::ArraySerializer.new(invitees, each_serializer: InviteeSerializer)
    end

    def should_display_invitees
      (object.public? && object.invitees.count > 0) ||
        (object.private? && object.raw_invitees.count > 0)
    end

    def category_id
      object.post.topic.category_id
    end

    def include_url?
      object.url.present?
    end

    def include_recurrence_rule?
      object.recurring?
    end

    def recurrence_rule
      RRuleConfigurator.rule(
        recurrence: object.recurrence,
        starts_at: object.starts_at.in_time_zone(object.timezone),
        recurrence_until: object.recurrence_until&.in_time_zone(object.timezone),
      )
    end
  end
end
