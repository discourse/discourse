# frozen_string_literal: true

# Responsible for creating or updating theme site settings, and in the case
# where the value is set to nil or is the same as the site setting default,
# deleting the theme site setting override.
#
# Theme site settings are used to override specific site settings that are
# marked as themeable in site_settings.yml. This allows themes to have a greater
# control over the full site experience.
#
# Theme site settings have an identical schema to SiteSetting.
class Themes::ThemeSiteSettingManager
  include Service::Base

  params do
    attribute :theme_id, :integer
    attribute :name
    attribute :value

    validates :theme_id, presence: true
    validates :name, presence: true

    after_validation { self.name = self.name.to_sym if self.name.present? }
  end

  policy :current_user_is_admin
  policy :ensure_setting_is_themeable
  model :theme
  model :existing_theme_site_setting, optional: true

  transaction do
    step :convert_new_value_to_site_setting_values
    step :upsert
    step :log_change
  end

  step :update_site_setting_cache

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def ensure_setting_is_themeable(params:)
    SiteSetting.themeable[params.name]
  end

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def fetch_existing_theme_site_setting(params:, theme:)
    theme.theme_site_settings.find_by(name: params.name)
  end

  def convert_new_value_to_site_setting_values(params:)
    if params.value.nil?
      context[:setting_db_value] = nil
      context[:setting_data_type] = nil
      context[:setting_ruby_value] = nil
      return
    end

    # This must be done because we want the schema and data of ThemeSiteSetting to reflect
    # that of SiteSetting, since they are the same data types and values.
    setting_db_value, setting_data_type =
      SiteSetting.type_supervisor.to_db_value(params.name, params.value)
    setting_ruby_value =
      SiteSetting.type_supervisor.to_rb_value(params.name, params.value, setting_data_type)

    context[:setting_db_value] = setting_db_value
    context[:setting_data_type] = setting_data_type
    context[:setting_ruby_value] = setting_ruby_value
  end

  def upsert(
    params:,
    existing_theme_site_setting:,
    theme:,
    setting_db_value:,
    setting_data_type:,
    setting_ruby_value:
  )
    setting_record = nil
    context[:previous_value] = nil
    context[:new_value] = nil

    if existing_theme_site_setting
      context[:previous_value] = existing_theme_site_setting.setting_rb_value
      setting_record = existing_theme_site_setting

      # If the setting is nil or matches the site setting default,
      # then we just update the existing theme site setting to reflect
      # this, as insurance against further changes to the site setting
      # default value.
      if params.value.nil? || setting_ruby_value == SiteSetting.defaults[params.name]
        new_db_value, _ =
          SiteSetting.type_supervisor.to_db_value(params.name, SiteSetting.defaults[params.name])
        new_ruby_value = SiteSetting.defaults[params.name]
      else
        new_db_value = setting_db_value
        new_ruby_value = setting_ruby_value
      end

      existing_theme_site_setting.update!(value: new_db_value)
      context[:new_value] = new_ruby_value
    else
      # If the setting is nil or matches the site setting default,
      # then we make a record using the site setting default as
      # insurance against further changes to the default value for
      # the site setting.
      if params.value.nil? || setting_ruby_value == SiteSetting.defaults[params.name]
        new_db_value, _ =
          SiteSetting.type_supervisor.to_db_value(params.name, SiteSetting.defaults[params.name])
        new_ruby_value = SiteSetting.defaults[params.name]
      else
        new_db_value = setting_db_value
        new_ruby_value = setting_ruby_value
      end

      setting_record =
        theme.theme_site_settings.create!(
          name: params.name,
          value: new_db_value,
          data_type: setting_data_type,
        )
      context[:new_value] = new_ruby_value
    end

    context[:theme_site_setting] = setting_record
  end

  def log_change(params:, new_value:, previous_value:, theme:, guardian:)
    StaffActionLogger.new(guardian.user).log_theme_site_setting_change(
      params.name,
      previous_value,
      new_value,
      theme,
    )
  end

  def update_site_setting_cache(theme:, params:, new_value:)
    # This also sends a MessageBus message to the client for client site settings,
    # and a DiscourseEvent for the change.
    SiteSetting.change_themeable_site_setting(theme.id, params.name, new_value)
  end
end
