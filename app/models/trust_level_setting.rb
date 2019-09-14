# frozen_string_literal: true

class TrustLevelSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    valid_values.any? { |v| v == val.to_i }
  end

  def self.values
    levels = TrustLevel.all
    @values ||= valid_values.map { |x|
      {
        name: x.is_a?(Integer) ? "#{x}: #{levels[x.to_i].name}" : x,
        value: x
      }
    }
  end

  def self.valid_values
    TrustLevel.valid_range.to_a
  end

  private_class_method :valid_values
end
