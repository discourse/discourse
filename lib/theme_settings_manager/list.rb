# frozen_string_literal: true

class ThemeSettingsManager::List < ThemeSettingsManager
  def list_type
    @opts[:list_type]
  end
end
