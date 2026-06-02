# frozen_string_literal: true

module DiscoursePostEvent
  class Invitee < ActiveRecord::Base
    self.table_name = "discourse_post_event_invitees"

    belongs_to :event, foreign_key: :post_id
    belongs_to :user

    default_scope do
      joins(:user)
        .includes(:user)
        .merge(User.not_suspended)
        .merge(User.not_silenced)
        .merge(User.not_staged)
        .where.not(users: { id: nil })
    end
    scope :with_status, ->(status) { where(status: Invitee.statuses[status]) }

    before_save :clear_recurring_unless_going
    after_commit :sync_chat_channel_members

    def self.statuses
      @statuses ||= Enum.new(going: 0, interested: 1, not_going: 2)
    end

    def self.create_attendance!(user_id, post_id, status, recurring: false)
      status = status.to_sym
      event = Event.find(post_id)

      if status == :going && event.at_capacity?
        raise Discourse::InvalidParameters.new(:max_attendees)
      end

      invitee = create!(post_id:, user_id:, status: statuses[status], recurring:)
      invitee.publish_attendance_change!
      invitee
    rescue ActiveRecord::RecordNotUnique
      # multiple attendances may be created concurrently — return the winning row
      find_by(post_id:, user_id:)
    end

    def update_attendance!(status, recurring: false)
      status = status&.to_sym

      if status == :going && event.at_capacity? && !going?
        raise Discourse::InvalidParameters.new(:max_attendees)
      end

      update!(status: self.class.statuses[status], recurring:)
      publish_attendance_change!
      self
    end

    def going?
      status == Invitee.statuses[:going]
    end

    def publish_attendance_change!
      event.publish_update!
      update_topic_tracking!
      DiscourseEvent.trigger(:discourse_calendar_post_event_invitee_status_changed, self)
    end

    def self.extract_uniq_usernames(groups)
      User.real.where(
        id: GroupUser.where(group_id: Group.where(name: groups).select(:id)).select(:user_id),
      )
    end

    def sync_chat_channel_members
      return if !event.chat_enabled?
      ChatChannelSync.sync(event)
    end

    def update_topic_tracking!
      topic_id = event.post.topic.id
      user_id = user.id
      tracking = :regular

      case status
      when Invitee.statuses[:going]
        tracking = :watching
      when Invitee.statuses[:interested]
        tracking = :tracking
      end

      TopicUser.change(
        user_id,
        topic_id,
        notification_level: TopicUser.notification_levels[tracking],
      )
    end

    private

    def clear_recurring_unless_going
      self.recurring = false unless going?
    end
  end
end

# == Schema Information
#
# Table name: discourse_post_event_invitees
#
#  id         :bigint           not null, primary key
#  notified   :boolean          default(FALSE), not null
#  recurring  :boolean          default(FALSE), not null
#  status     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  discourse_post_event_invitees_post_id_user_id_idx  (post_id,user_id) UNIQUE
#
