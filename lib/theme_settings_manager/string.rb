# frozen_string_literal: true

class ThemeSettingsManager::String < ThemeSettingsManager
  def is_valid_value?(new_value)
    (@opts[:min]..@opts[:max]).include? new_value.to_s.length
  end

  def textarea
    @opts[:textarea]
  end

  def json_schema
    begin
      JSON.parse(@opts[:json_schema])
    rescue StandardError
      false
    end
  end
end
