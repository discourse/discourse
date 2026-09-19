# frozen_string_literal: true

class ThemeSettingsManager::String < ThemeSettingsManager
  def textarea
    @opts[:textarea]
  end

  def json_schema
    JSON.parse(@opts[:json_schema])
  rescue StandardError
    false
  end
end
