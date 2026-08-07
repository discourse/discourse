# frozen_string_literal: true

class ThemeSettingsManager::List < ThemeSettingsManager
  def list_type
    @opts[:list_type]
  end

  def resolve_group_membership?
    @opts[:resolve_group_membership] && list_type == "group"
  end

  def value=(new_value)
    if list_type == "group" && disallowed_groups.present?
      disallowed_ids = disallowed_groups.to_s.split("|")
      new_value = new_value.to_s.split("|").reject { |id| disallowed_ids.include?(id) }.join("|")
    end

    super
  end
end
