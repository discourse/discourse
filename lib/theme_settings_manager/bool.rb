# frozen_string_literal: true

class ThemeSettingsManager::Bool < ThemeSettingsManager
  def self.cast(value)
    [true, "true"].include?(value)
  end

  def value
    self.class.cast(super)
  end

  def value=(new_value)
    new_value = (self.class.cast(new_value)).to_s
    super(new_value)
  end
end
