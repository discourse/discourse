# frozen_string_literal: true

module Migrations::Importer::Steps
  class SiteSettingsWithDependencies < Base::SiteSettings
    title "Importing site settings with dependencies"

    # TODO Add :emojis as dependency
    depends_on :categories, :groups, :tags, :uploads, :users

    private

    def skip_row?(row)
      name = row[:name].to_sym
      setting = @settings_index[name]
      return true if setting.nil?

      DATATYPES_WITH_DEPENDENCY.exclude?(setting[:type])
    end

    def transform_value(setting_name, value, type)
      case ::SiteSettings::TypeSupervisor.types[type.to_sym]
      when Enums::SiteSettingDatatype::CATEGORY, Enums::SiteSettingDatatype::CATEGORY_LIST
        map_ids(setting_name, value, MappingType::CATEGORIES, "category")
      when Enums::SiteSettingDatatype::EMOJI_LIST
        value # TODO Figure out, if we need to map emojis
      when Enums::SiteSettingDatatype::GROUP
        value # TODO Map group name (and update documentation in site_settings.yml which states it's an ID, not name)
      when Enums::SiteSettingDatatype::GROUP_LIST
        map_ids(setting_name, value, MappingType::GROUPS, "group")
      when Enums::SiteSettingDatatype::TAG_GROUP_LIST
        # TODO Map tag group names
        value
      when Enums::SiteSettingDatatype::TAG_LIST
        value # TODO Map tag names
      when Enums::SiteSettingDatatype::UPLOAD
        map_ids(setting_name, value, MappingType::UPLOADS, "upload").to_i
      when Enums::SiteSettingDatatype::UPLOADED_IMAGE_LIST
        map_ids(setting_name, value, MappingType::UPLOADS, "upload")
      when Enums::SiteSettingDatatype::USERNAME
        map_username(setting_name, value)
      else
        raise "Unknown type: #{type}"
      end
    end

    private

    def map_ids(setting_name, value, mapping_type, type_name)
      value
        .split(LIST_SEPARATOR)
        .map do |original_id|
          unless (discourse_id = query_discourse_id(mapping_type, original_id))
            log_error(
              "Failed to update site setting '#{setting_name}': " \
                "Could not map original #{type_name} ID '#{original_id}' to Discourse ID",
            )
          end
          discourse_id
        end
        .compact
        .join(LIST_SEPARATOR)
    end

    def query_discourse_id(mapping_type, original_id)
      @intermediate_db.query_value(<<~SQL, mapping_type, original_id)
        SELECT discourse_id
        FROM mapped.ids
        WHERE type = ?1
          AND original_id = ?2
      SQL
    end

    def map_username(setting_name, original_username)
      original_username = User.normalize_username(original_username)
      discourse_username = @intermediate_db.query_value(<<~SQL, original_username)
        SELECT discourse_username
        FROM mapped.usernames
        WHERE original_username = ?
      SQL

      if discourse_username.blank?
        if !(discourse_username = User.where(username_lower: original_username).pick(:username))
          log_error(
            "Failed to update site setting '#{setting_name}': " \
              "Could not map original username '#{original_username}' to Discourse username",
          )
        end
      end

      discourse_username
    end
  end
end
