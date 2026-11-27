# frozen_string_literal: true

class CopyExternalConcordThemeSettings < ActiveRecord::Migration[8.1]
  # Seeds install the system theme at this ID after migrations have run.
  CONCORD_SYSTEM_THEME_ID = -3

  # ThemeSetting data types and the Concord settings supported at the time of the move.
  STRING = 2
  BOOL = 3
  LIST = 4
  OBJECTS = 7

  SETTING_TYPES = {
    "include_tags" => BOOL,
    "include_chat_channels" => BOOL,
    "show_logo" => BOOL,
    "home_link" => BOOL,
    "ai_conversations_link" => BOOL,
    "remember_last_channel" => BOOL,
    "chat_container_category" => STRING,
    "sidebar_sections" => OBJECTS,
    "member_list_roles" => LIST,
  }.freeze

  def up
    concord_source_theme_id = concord_existing_remote_theme_id
    return unless concord_source_theme_id

    defaults = concord_existing_remote_theme_defaults(concord_source_theme_id)
    return if defaults.empty?

    settings = DB.query(<<~SQL, concord_source_theme_id:)
      SELECT id, name, data_type, value, json_value::text AS json
      FROM theme_settings
      WHERE theme_id = :concord_source_theme_id
      ORDER BY id
    SQL

    copied = 0
    settings.each do |setting|
      next unless defaults.key?(setting.name)

      name = setting.name == "sidebar_groups" ? "sidebar_sections" : setting.name
      next unless SETTING_TYPES[name] == setting.data_type
      next unless copy_override?(setting, defaults.fetch(setting.name))

      copied += copy_setting(setting.id, name)
    end

    return if copied.zero?

    DB.exec(<<~SQL, theme_id: CONCORD_SYSTEM_THEME_ID)
      UPDATE theme_fields SET value_baked = NULL
      WHERE theme_id = :theme_id AND value_baked IS NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def concord_existing_remote_theme_id
    ids = DB.query_single(<<~SQL)
      SELECT themes.id
      FROM themes
      JOIN remote_themes ON remote_themes.id = themes.remote_theme_id
      WHERE NOT themes.component AND remote_themes.remote_url ~*
        '^(https://|ssh://git@)github[.]com/discourse/discourse-concord-theme([.]git)?/*$'
      ORDER BY themes.id
    SQL
    return ids.first if ids.size <= 1

    default_id =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'default_theme_id'").first.to_i
    return default_id if ids.include?(default_id)

    say "Skipping ambiguous external Concord installs #{ids.join(", ")}"
    nil
  end

  def concord_existing_remote_theme_defaults(concord_source_theme_id)
    yaml = DB.query_single(<<~SQL, concord_source_theme_id:).first
      SELECT value FROM theme_fields
      WHERE theme_id = :concord_source_theme_id AND target_id = 3 AND name = 'yaml' AND error IS NULL
    SQL
    definitions = YAML.safe_load(yaml) if yaml.present?
    return {} unless definitions.is_a?(Hash)

    # Older versions called the sidebar setting sidebar_groups.
    definitions.delete("sidebar_groups") if definitions.key?("sidebar_sections")
    definitions.transform_values do |definition|
      definition.is_a?(Hash) ? definition["default"] : definition
    end
  rescue Psych::Exception => e
    say "Skipping unreadable settings schema for Concord theme #{concord_source_theme_id}: #{e.message}"
    {}
  end

  def copy_override?(setting, default)
    return setting.value != default.to_s unless setting.data_type == OBJECTS

    sections = JSON.parse(setting.json) if setting.json
    return false if sections == default
    return true if valid_sections?(sections)

    say "Skipping incompatible sidebar layout from Concord theme setting #{setting.id}"
    false
  end

  def valid_sections?(sections)
    return false unless sections.is_a?(Array)

    sections.all? do |section|
      next false unless section.is_a?(Hash)
      next false unless section["name"].is_a?(String) && section["name"].present?

      channels = section["channels"]
      next true if channels.nil?

      channels.is_a?(Array) && channels.all? { |channel| valid_channel?(channel) }
    end
  end

  def valid_channel?(channel)
    channel.is_a?(Hash) && channel["id"].is_a?(Integer) &&
      %w[text voice forum tag].include?(channel["type"])
  end

  def copy_setting(id, name)
    DB.exec(<<~SQL, id:, name:, theme_id: CONCORD_SYSTEM_THEME_ID)
      INSERT INTO theme_settings (theme_id, name, data_type, value, json_value, created_at, updated_at)
      SELECT :theme_id, :name, data_type, value, json_value, NOW(), NOW()
      FROM theme_settings
      WHERE id = :id
        AND NOT EXISTS (SELECT 1 FROM theme_settings WHERE theme_id = :theme_id AND name = :name)
    SQL
  end
end
