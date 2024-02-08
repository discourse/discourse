# frozen_string_literal: true

class ThemeSettingsManager::Enum < ThemeSettingsManager
  def value
    val = super
    match = choices.find { |choice| choice == val || choice.to_s == val }
    match || val
  end

  def is_valid_value?(new_value)
    choices.include?(new_value) || choices.map(&:to_s).include?(new_value)
  end

  def choices
    @opts[:choices]
  end
end
