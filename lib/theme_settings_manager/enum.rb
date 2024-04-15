# frozen_string_literal: true

class ThemeSettingsManager::Enum < ThemeSettingsManager
  def value
    val = super
    match = choices.find { |choice| choice == val || choice.to_s == val }
    match || val
  end

  def choices
    @opts[:choices]
  end
end
