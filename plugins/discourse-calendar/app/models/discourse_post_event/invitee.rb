# frozen_string_literal: true

module DiscoursePostEvent
  class Invitee < ActiveRecord::Base
    UNKNOWN_ATTENDANCE = "unknown"

    self.table_name = "discourse_post_event_invitees"

    belongs_to :event, foreign_key: :post_id
    belongs_to :user

    default_scope { joins(:user).includes(:user).where("users.id IS NOT NULL") }
    scope :with_status, ->(status) { where(status: Invitee.statuses[status]) }

    after_commit :sync_chat_channel_members

    def self.statuses
      @statuses ||= Enum.new(going: 0, interested: 1, not_going: 2)
    end

    def self.create_attendance!(user_id, post_id, status)
      invitee =
        Invitee.create!(status: Invitee.statuses[status.to_sym], post_id: post_id, user_id: user_id)
      invitee.event.publish_update!
      invitee.update_topic_tracking!
      DiscourseEvent.trigger(:discourse_calendar_post_event_invitee_status_changed, invitee)
      invitee
    rescue ActiveRecord::RecordNotUnique
      # do nothing in case multiple new attendances would be created very fast
      Invitee.find_by(post_id: post_id, user_id: user_id)
    end

    def update_attendance!(status)
      new_status = Invitee.statuses[status.to_sym]
      status_changed = self.status != new_status
      self.update(status: new_status)
      self.event.publish_update!
      self.update_topic_tracking! if status_changed
      DiscourseEvent.trigger(:discourse_calendar_post_event_invitee_status_changed, self)
      self
    end

    def self.extract_uniq_usernames(groups)
      User.real.where(
        id: GroupUser.where(group_id: Group.where(name: groups).select(:id)).select(:user_id),
      )
    end

    def sync_chat_channel_members
      return if !self.event.chat_enabled?
      ChatChannelSync.sync(self.event)
    end

    def update_topic_tracking!
      topic_id = self.event.post.topic.id
      user_id = self.user.id
      tracking = :regular

      case self.status
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
  end
end

# == Schema Information
#
# Table name: discourse_post_event_invitees
#
#  id         :bigint           not null, primary key
#  post_id    :integer          not null
#  user_id    :integer          not null
#  status     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  notified   :boolean          default(FALSE), not null
#
# Indexes
#
#  discourse_post_event_invitees_post_id_user_id_idx  (post_id,user_id) UNIQUE
#
