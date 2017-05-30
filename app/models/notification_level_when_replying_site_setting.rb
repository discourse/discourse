require_dependency 'enum_site_setting'
require_dependency 'notification_levels'

class NotificationLevelWhenReplyingSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    values.any? { |v| v[:value] == val.to_i }
  end

  def self.notification_levels
    NotificationLevels.topic_levels
  end

  def self.values
    @values ||= [
      { name: 'topic.notifications.watching.title', value: notification_levels[:watching] },
      { name: 'topic.notifications.tracking.title', value: notification_levels[:tracking] },
      { name: 'topic.notifications.regular.title', value: notification_levels[:regular] }
    ]
  end

  def self.translate_names?
    true
  end

end
