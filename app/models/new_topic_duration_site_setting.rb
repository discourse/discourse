# frozen_string_literal: true

class NewTopicDurationSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    values.any? { |v| v[:value] == val.to_i }
  end

  def self.values
    @values ||= [
      { name: 'user.new_topic_duration.not_viewed',    value: -1 },
      { name: 'user.new_topic_duration.after_1_day',   value: 60 * 24 },
      { name: 'user.new_topic_duration.after_2_days',  value: 60 * 24 * 2 },
      { name: 'user.new_topic_duration.after_1_week',  value: 60 * 24 * 7 },
      { name: 'user.new_topic_duration.after_2_weeks', value: 60 * 24 * 7 * 2 },
      { name: 'user.new_topic_duration.last_here',     value: -2 },
    ]
  end

  def self.translate_names?
    true
  end

end
