# frozen_string_literal: true

class ThemeSettingsManager::List < ThemeSettingsManager
  def value
    alias_everyone_to_logged_in_users(normalized(super))
  end

  def default_value
    alias_everyone_to_logged_in_users(normalized(super))
  end

  def value_for_editing
    return super if list_type != "group"

    normalized(configured_value)
  end

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

  private

  # Rules are declared against stored ids, so they have to run before the display
  # alias below. Aliasing first would turn a stored 0 into 5, and a rule that
  # disallows 0 would never match it again.
  def normalized(value)
    list_type == "group" ? constraints.normalize(value) : value
  end

  def alias_everyone_to_logged_in_users(value)
    if list_type != "group" || !SiteSetting.granular_anonymous_and_logged_in_groups_permissions
      return value
    end

    everyone_id = Group::AUTO_GROUPS[:everyone].to_s
    logged_in_users_id = Group::AUTO_GROUPS[:logged_in_users].to_s

    value.to_s.split("|").map { |id| id == everyone_id ? logged_in_users_id : id }.uniq.join("|")
  end
end
