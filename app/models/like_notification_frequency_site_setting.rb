# frozen_string_literal: true

class LikeNotificationFrequencySiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    values.any? { |v| v[:value] == val.to_i }
  end

  def self.values
    @values ||= [
      { name: 'user.like_notification_frequency.always',  value:  0 },
      { name: 'user.like_notification_frequency.first_time_and_daily',   value:  1 },
      { name: 'user.like_notification_frequency.first_time', value:  2 },
      { name: 'user.like_notification_frequency.never', value:  3 },
    ]
  end

  def self.translate_names?
    true
  end

end
