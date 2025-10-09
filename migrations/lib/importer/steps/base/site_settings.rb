# frozen_string_literal: true

module Migrations::Importer::Steps::Base
  class SiteSettings < ::Migrations::Importer::Step
    class << self
      def inherited(klass)
        super

        klass.requires_mapping :last_change_dates, "SELECT name, updated_at FROM site_settings"
      end
    end

    DATATYPES_WITH_DEPENDENCY =
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
    private_constant :DATATYPES_WITH_DEPENDENCY

    def execute
      super

      @log_messages = []
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

      rows = rows.reject { |row| skipped_row?(row) }

      with_progressbar(rows.size) do
        log_deprecations do
          rows.each do |row|
            @stats.reset
            failed_setting_size = @failed_settings.size

            import(row) if importable?(row)
            update_progressbar if failed_setting_size == @failed_settings.size
          end

          failed_setting_size = @failed_settings.size
          retry_failed_settings
          update_progressbar(increment_by: failed_setting_size)
        end
      end

      # TODO Use logging framework when it's implemented
      @log_messages.each { |message| puts "      #{message}" }
    end

    protected

    def skipped_row?(row)
      false
    end

    def transform_value(value, type)
      value
    end

    private

    def importable?(row)
      row in { name:, import_mode: }
      setting = @all_settings_by_name[name.to_sym]

      if setting.nil?
        log_warning "Ignoring unknown site setting: #{name}"
        return false
      end

      if setting[:themeable]
        log_warning "Can't modify themeable site setting: #{name}"
        return false
      end

      if SiteSetting.shadowed_settings.include?(name)
        log_warning "Can't modify shadowed site setting: #{name}"
        return false
      end

      type = setting[:type]
      if import_mode == Enums::SiteSettingImportMode::APPEND && !type.end_with?("list")
        log_warning "Can't append to a site setting of type '#{type}': #{name}"
        return false
      end

      true
    end

    def import(row)
      row in { name:, value:, last_changed_at:, import_mode: }
      setting = @all_settings_by_name[name.to_sym]

      case import_mode
      when Enums::SiteSettingImportMode::AUTO
        smart_import(setting, value, last_changed_at)
      when Enums::SiteSettingImportMode::APPEND
        append(setting, value)
      when Enums::SiteSettingImportMode::OVERRIDE
        set_and_log(setting, transform_value(value, setting[:type]))
      end
    end

    def smart_import(setting, value, last_changed_at)
      name = setting[:setting]
      last_changed_at ||= Time.now
      existing_last_changed_at = @last_change_dates[name]

      if !existing_last_changed_at || existing_last_changed_at < last_changed_at
        set_and_log(setting, transform_value(value, setting[:type]))
      else
        @stats.skip_count += 1
      end
    end

    def append(setting, value)
      name = setting[:setting]
      type = setting[:type]
      existing_values = (SiteSetting.get(name) || "").split("|").to_set

      values_to_append = (value || "").split("|").map { |v| transform_value(v, type) }
      values = existing_values.merge(values_to_append)

      set_and_log(setting, values.join("|"))
    end

    def set_and_log(setting, value)
      if setting[:value] == value
        @stats.skip_count += 1
        return
      end

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
        shuffled_failed_settings = @failed_settings.shuffle
        @failed_settings = []

        shuffled_failed_settings.each { |f| set_and_log(f[:setting], f[:value]) }
      end

      @failed_settings.each do |failed|
        name = failed[:setting][:setting]
        exception = failed[:exception]

        log_error "Failed to update site setting '#{name}': #{exception.message}"
      end
    end

    def with_overridden_deprecate(impl)
      original = Discourse.method(:deprecate)
      Discourse.define_singleton_method(:deprecate, impl)
      begin
        yield
      ensure
        Discourse.define_singleton_method(:deprecate, original)
      end
    end

    def without_deprecate_warnings
      with_overridden_deprecate(->(_warning, **_kwargs) {}) { yield }
    end

    def log_deprecations
      logged_site_settings = Set.new
      with_overridden_deprecate(
        ->(warning, **_kwargs) do
          setting_name = warning[/`SiteSetting\.(.*?)=?`.*/, 1]
          log_warning warning if logged_site_settings.exclude?(setting_name)
          logged_site_settings << setting_name
        end,
      ) { yield }
    end

    def log_warning(warning)
      @log_messages << warning
      @stats.warning_count += 1
    end

    def log_error(error)
      @log_messages << error
      @stats.error_count += 1
    end
  end
end
