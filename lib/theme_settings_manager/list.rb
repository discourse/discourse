# frozen_string_literal: true

class ThemeSettingsManager::List < ThemeSettingsManager
  def value
    alias_everyone_to_logged_in_users(super)
  end

  def default_value
    alias_everyone_to_logged_in_users(super)
  end

  def value_for_editing
    return super if list_type != "group"

    configured_value
  end

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

  private

  def alias_everyone_to_logged_in_users(value)
    if list_type != "group" || !SiteSetting.granular_anonymous_and_logged_in_groups_permissions
      return value
    end

    everyone_id = Group::AUTO_GROUPS[:everyone].to_s
    logged_in_users_id = Group::AUTO_GROUPS[:logged_in_users].to_s

    value.to_s.split("|").map { |id| id == everyone_id ? logged_in_users_id : id }.uniq.join("|")
  end
end
