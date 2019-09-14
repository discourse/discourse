# frozen_string_literal: true

class AutoTrackDurationSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    values.any? { |v| v[:value] == val.to_i }
  end

  def self.values
    @values ||= [
      { name: 'user.auto_track_options.never',            value: -1 },
      { name: 'user.auto_track_options.immediately',      value: 0 },
      { name: 'user.auto_track_options.after_30_seconds', value: 1000 * 30 },
      { name: 'user.auto_track_options.after_1_minute',   value: 1000 * 60 },
      { name: 'user.auto_track_options.after_2_minutes',  value: 1000 * 60 * 2 },
      { name: 'user.auto_track_options.after_3_minutes',  value: 1000 * 60 * 3 },
      { name: 'user.auto_track_options.after_4_minutes',  value: 1000 * 60 * 4 },
      { name: 'user.auto_track_options.after_5_minutes',  value: 1000 * 60 * 5 },
      { name: 'user.auto_track_options.after_10_minutes', value: 1000 * 60 * 10 },
    ]
  end

  def self.translate_names?
    true
  end

end
