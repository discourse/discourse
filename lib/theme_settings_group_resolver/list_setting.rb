# frozen_string_literal: true

class ThemeSettingsGroupResolver
  # Resolves one top-level group list setting into a boolean and removes the
  # original group IDs from the frontend payload.
  #
  # c.f. ThemeSettingsGroupResolver.resolve
  #
  # Example:
  #   input: { allowed_groups: "1|2" }
  #   output: { user_in_allowed_groups: true }
  class ListSetting
    def self.applies?(setting_info)
      setting_info[:type] == "list" && setting_info[:resolve_group_membership]
    end

    def initialize(setting_name:, setting_info:, guardian:)
      @setting_name = setting_name
      @guardian = guardian
    end

    def resolve!(settings)
      group_ids = settings.delete(@setting_name).to_s.split("|").map(&:to_i)
      settings[:"user_in_#{@setting_name}"] = @guardian.in_any_groups?(group_ids)
    end
  end
end
