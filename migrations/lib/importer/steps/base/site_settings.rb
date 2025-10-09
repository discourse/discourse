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
      @audit_message = I18n.t("importer.site_setting_log_message")
      @failed_settings = []

      @settings_index =
        silence_deprecation_warnings do
          SiteSetting.all_settings(include_hidden: true)
        end.index_by { |hash| hash[:setting] }

      import_rows = fetch_rows.reject { |row| skip_row?(row) }

      with_progressbar(import_rows.size) do
        capture_deprecation_warnings { process_rows(import_rows) }
      end

      # TODO: Replace with logging when available
      @log_messages.each { |message| puts "      #{message}" }
    end

    protected

    # Override in subclasses to skip rows that should be handled in a later step.
    def skip_row?(_row)
      false
    end

    # Override in subclasses to adapt/normalize values by type.
    def transform_value(value, _type)
      value
    end

    private

    def fetch_rows
      @intermediate_db.query <<~SQL
        SELECT name, value, last_changed_at, import_mode
        FROM site_settings
        ORDER BY ROWID
      SQL
    end

    def process_rows(rows)
      rows.each do |row|
        @stats.reset
        before_fail_count = @failed_settings.size

        import_row(row) if row_importable?(row)

        # Only advance the progress bar if the row didn't get deferred due to failure.
        update_progressbar if before_fail_count == @failed_settings.size
      end

      # Re-attempt failed updates (often due to dependency ordering).
      failures_before_retry = @failed_settings.size
      retry_failed_updates
      update_progressbar(increment_by: failures_before_retry)
    end

    def row_importable?(row)
      row in { name:, import_mode: }
      setting = @settings_index[name.to_sym]

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

    def import_row(row)
      row in { name:, value:, last_changed_at:, import_mode: }
      setting = @settings_index[name.to_sym]

      case import_mode
      when Enums::SiteSettingImportMode::AUTO
        auto_import(setting, value, last_changed_at)
      when Enums::SiteSettingImportMode::APPEND
        append_to_list(setting, value)
      when Enums::SiteSettingImportMode::OVERRIDE
        set_and_log(setting, transform_value(value, setting[:type]))
      end
    end

    def auto_import(setting, value, last_changed_at)
      name = setting[:setting]
      last_changed_at ||= Time.now
      existing_last_changed_at = @last_change_dates[name]

      if !existing_last_changed_at || existing_last_changed_at < last_changed_at
        set_and_log(setting, transform_value(value, setting[:type]))
      else
        @stats.skip_count += 1
      end
    end

    def append_to_list(setting, value)
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
        SiteSetting.set_and_log(name, value, Discourse.system_user, @audit_message)
      rescue StandardError => exception
        @failed_settings << { setting:, value:, exception: }
      end
    end

    def retry_failed_updates
      previous_count = nil

      while @failed_settings.any? && @failed_settings.size != previous_count
        previous_count = @failed_settings.size
        shuffled = @failed_settings.shuffle
        @failed_settings = []
        shuffled.each { |f| set_and_log(f[:setting], f[:value]) }
      end

      @failed_settings.each do |failed|
        name = failed[:setting][:setting]
        exception = failed[:exception]
        log_error "Failed to update site setting '#{name}': #{exception.message}"
      end
    end

    def with_temporary_deprecate_handler(impl)
      original = Discourse.method(:deprecate)
      Discourse.define_singleton_method(:deprecate, impl)
      begin
        yield
      ensure
        Discourse.define_singleton_method(:deprecate, original)
      end
    end

    def silence_deprecation_warnings
      with_temporary_deprecate_handler(->(_warning, **_kwargs) {}) { yield }
    end

    def capture_deprecation_warnings
      logged_settings = Set.new

      with_temporary_deprecate_handler(
        ->(warning, **_kwargs) do
          setting_name = warning[/`SiteSetting\.(.*?)=?`.*/, 1]
          log_warning warning if setting_name && logged_settings.add?(setting_name)
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
