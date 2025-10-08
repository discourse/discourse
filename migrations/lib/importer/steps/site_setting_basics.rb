# frozen_string_literal: true

module Migrations::Importer::Steps
  class SiteSettingBasics < ::Migrations::Importer::Step
    title "Importing basic site settings"
    priority 0

    requires_mapping :last_change_dates, "SELECT name, updated_at FROM site_settings"

    SKIPPED_DATATYPES =
      [
        Enums::SiteSettingDatatype::CATEGORY,
        Enums::SiteSettingDatatype::CATEGORY_LIST,
        Enums::SiteSettingDatatype::EMOJI_LIST,
        Enums::SiteSettingDatatype::GROUP,
        Enums::SiteSettingDatatype::GROUP_LIST,
        Enums::SiteSettingDatatype::TAG_GROUP_LIST,
        Enums::SiteSettingDatatype::TAG_LIST,
        Enums::SiteSettingDatatype::UPLOAD,
        Enums::SiteSettingDatatype::UPLOADED_IMAGE_LIST,
        Enums::SiteSettingDatatype::USERNAME,
      ].map { |number| ::SiteSettings::TypeSupervisor.types[number].to_s }
    private_constant :SKIPPED_DATATYPES

    def execute
      super

      @log_message = I18n.t("importer.site_setting_log_message")

      @all_settings_by_name =
        without_deprecate_warnings do
          SiteSetting.all_settings(include_hidden: true)
        end.index_by { |hash| hash[:setting] }

      @failed_settings = []

      rows = @intermediate_db.query <<~SQL
        SELECT name, value, last_changed_at, import_mode
        FROM site_settings
        ORDER BY ROWID
      SQL

      log_deprecations do
        rows.each do |row|
          row in { name:, value:, last_changed_at:, import_mode: }
          setting = @all_settings_by_name[name.to_sym]

          next unless importable?(setting, name, import_mode)
          import(setting, value, last_changed_at, import_mode)
        end
      end
    end

    private

    def importable?(setting, name, import_mode)
      if setting.nil?
        puts "Ignoring unknown site setting: #{name}"
        return false
      end

      type = setting[:type]

      if SKIPPED_DATATYPES.include?(type)
        # settings of this type will be handled in a different step
        return false
      end

      if setting[:themeable]
        puts "Can't modify themeable site setting: #{name}"
        return false
      end

      if SiteSetting.shadowed_settings.include?(name)
        puts "Can't modify shadowed site setting: #{name}"
        return false
      end

      if import_mode == Enums::SiteSettingImportMode::APPEND && !type.end_with?("list")
        puts "Can't append to a site setting of type '#{type}': #{name}"
        return false
      end

      true
    end

    def import(setting, value, last_changed_at, import_mode)
      case import_mode
      when Enums::SiteSettingImportMode::AUTO
        smart_import(setting, value, last_changed_at)
      when Enums::SiteSettingImportMode::APPEND
        append(setting, value)
      when Enums::SiteSettingImportMode::OVERRIDE
        set_and_log(setting, value)
      end
    end

    def smart_import(setting, value, last_changed_at)
      name = setting[:setting]
      last_changed_at ||= Time.now
      existing_last_changed_at = @last_change_dates[name]

      if !existing_last_changed_at || existing_last_changed_at < last_changed_at
        set_and_log(setting, value)
      end
    end

    def append(setting, value)
      name = setting[:setting]
      existing_values = (SiteSetting.get(name) || "").split("|").to_set

      values_to_append = (value || "").split("|")
      values = existing_values.merge(values_to_append)

      set_and_log(setting, values.join("|"))
    end

    def set_and_log(setting, value)
      return if setting[:value] == value

      name = setting[:setting]

      begin
        SiteSetting.set_and_log(name, value, Discourse.system_user, @log_message)
      rescue StandardError => exception
        @failed_settings << { setting:, value:, exception: }
      end
    end

    def retry_failed_settings
      previous_count = nil

      while @failed_settings.any? && @failed_settings.size != previous_count
        previous_count = @failed_settings.size
        previously_failed_settings = @failed_settings.shuffle
        @failed_settings = []

        previously_failed_settings.each { |failed| set_and_log(failed[:setting], failed[:value]) }
      end

      @failed_settings.each do |failed|
        name = failed[:setting][:name]
        exception = failed[:exception]

        puts "Failed to update site setting: #{name}"
        puts exception.message
        puts exception.backtrace.join("\n")
      end
    end

    def without_deprecate_warnings
      original = Discourse.method(:deprecate)
      Discourse.define_singleton_method(:deprecate) { |warning, **kwargs| }
      begin
        yield
      ensure
        Discourse.define_singleton_method(:deprecate, original)
      end
    end

    def log_deprecations
      original = Discourse.method(:deprecate)
      Discourse.define_singleton_method(:deprecate) { |warning, **kwargs| puts warning }
      begin
        yield
      ensure
        Discourse.define_singleton_method(:deprecate, original)
      end
    end
  end
end
