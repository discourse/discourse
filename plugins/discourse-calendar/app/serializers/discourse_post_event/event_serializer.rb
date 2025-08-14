# frozen_string_literal: true

module DiscoursePostEvent
  class EventSerializer < BasicEventSerializer
    attributes :can_act_on_discourse_post_event
    attributes :can_update_attendance
    attributes :creator
    attributes :custom_fields
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
    attributes :recurrence_until
    attributes :reminders
    attributes :sample_invitees
    attributes :should_display_invitees
    attributes :stats
    attributes :status
    attributes :url
    attributes :description
    attributes :location
    attributes :watching_invitee
    attributes :chat_enabled
    attributes :channel
    attributes :rrule
    attributes :max_attendees
    attributes :at_capacity

    def channel
      ::Chat::ChannelSerializer.new(object.chat_channel, root: false, scope:)
    end

    def include_channel?
      object.chat_enabled && defined?(::Chat::ChannelSerializer) && object.chat_channel.present?
    end

    def at_capacity
      object.at_capacity?
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

    def include_url?
      object.url.present?
    end
  end
end
