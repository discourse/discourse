# frozen_string_literal: true

class TopicNotifier
  def initialize(topic)
    @topic = topic
  end

  { watch!: :watching,
    track!: :tracking,
    regular!: :regular,
    mute!: :muted }.each_pair do |method_name, level|

    define_method method_name do |user_id|
      change_level user_id, level
    end

  end

  def watch_topic!(user_id, reason = :created_topic)
    change_level user_id, :watching, reason
  end

  # Enable/disable the mute on the topic
  def toggle_mute(user_id)
    change_level user_id, (muted?(user_id) ? levels[:regular] : levels[:muted])
  end

  def muted?(user_id)
    tu = @topic.topic_users.find_by(user_id: user_id)
    tu && tu.notification_level == levels[:muted]
  end

  private

  def levels
    @notification_levels ||= TopicUser.notification_levels
  end

  def change_level(user_id, level, reason = nil)
    attrs = { notification_level: levels[level] }
    attrs.merge!(notifications_reason_id: TopicUser.notification_reasons[reason]) if reason
    TopicUser.change(user_id, @topic.id, attrs)
  end
end
