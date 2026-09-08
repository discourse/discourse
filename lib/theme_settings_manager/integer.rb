# frozen_string_literal: true

class ThemeSettingsManager::Integer < ThemeSettingsManager
  class << self
    def cast(value)
      value.to_i
    end
  end

  def value
    self.class.cast(super)
  end

  def value=(new_value)
    super(self.class.cast(new_value))
  end
end
