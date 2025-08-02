# frozen_string_literal: true

class ThemeSettingsManager::Float < ThemeSettingsManager
  def self.cast(value)
    value.to_f
  end

  def value
    self.class.cast(super)
  end

  def value=(new_value)
    super(self.class.cast(new_value))
  end
end
