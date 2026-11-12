# frozen_string_literal: true

require_relative "theme_settings_group_resolver/list_setting"
require_relative "theme_settings_group_resolver/object_setting"

# Rewrites theme settings that opted into server-side group membership resolution,
# via the resolve_group_membership property in the theme settings schema.
#
# Example:
#   settings_hash: { allowed_groups: "1|2", title: "Welcome" }
#   type_info: { allowed_groups: { type: "list", resolve_group_membership: true } }
#   output: { user_in_allowed_groups: true, title: "Welcome" }
class ThemeSettingsGroupResolver
  RESOLVERS = [ThemeSettingsGroupResolver::ListSetting, ThemeSettingsGroupResolver::ObjectSetting]

  def self.resolve(settings_hash:, type_info:, guardian:)
    new(settings_hash:, type_info:, guardian:).resolve
  end

  def initialize(settings_hash:, type_info:, guardian:)
    @settings_hash = settings_hash
    @type_info = type_info || {}
    @guardian = guardian
  end

  def resolve
    @type_info.each_with_object(@settings_hash.dup) do |(setting_name, setting_info), settings|
      resolver_class = RESOLVERS.find { |resolver| resolver.applies?(setting_info) }
      next if !resolver_class

      resolver_class.new(setting_name:, setting_info:, guardian: @guardian).resolve!(settings)
    end
  end
end
