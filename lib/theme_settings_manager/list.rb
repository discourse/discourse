# frozen_string_literal: true

class ThemeSettingsManager::List < ThemeSettingsManager
  def list_type
    @opts[:list_type]
  end

  def resolve_group_membership?
    @opts[:resolve_group_membership] && list_type == "group"
  end
end
