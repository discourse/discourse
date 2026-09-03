# frozen_string_literal: true

class ThemeSettingsManager::List < ThemeSettingsManager
  def list_type
    @opts[:list_type]
  end

  def resolve_group_membership?
    @opts[:resolve_group_membership] && list_type == "group"
  end

  def value=(new_value)
    new_value = constraints.normalize!(new_value, name:) if list_type == "group"

    super
  end

  def value
    current_value = super
    list_type == "group" ? constraints.normalize(current_value) : current_value
  end
end
