# frozen_string_literal: true

class ThemeSettingsManager::Bool < ThemeSettingsManager
  class << self
    def cast(value)
      [true, "true"].include?(value)
    end
  end

  def value
    self.class.cast(super)
  end

  def value=(new_value)
    new_value = self.class.cast(new_value).to_s
    super(new_value)
  end
end
