# frozen_string_literal: true

class Themes::ThemeSiteSettingUpsert
  include Service::Base

  params do
    attribute :theme_id, :integer
    attribute :name
    attribute :value, :string

    validates :theme_id, presence: true
    validates :name, presence: true

    after_validation do
      self.name = self.name.to_sym
      self.value = self.value || nil
    end
  end

  # TODO (martin) Need any sort of policies here?
  # * Validate setting is themeable (take this from model)
  # * Validate type of setting is okay?
  # * Validate user is admin

  model :theme
  model :existing_theme_site_setting, optional: true

  transaction do
    step :convert_new_value_to_site_setting_values
    step :save_update_or_destroy
  end

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def fetch_existing_theme_site_setting(params:, theme:)
    theme.theme_site_settings.find_by(name: params.name)
  end

  def convert_new_value_to_site_setting_values(params:)
    return if params.value.nil?

    setting_db_value, setting_data_type =
      SiteSetting.type_supervisor.to_db_value(params.name, params.value)
    setting_ruby_value =
      SiteSetting.type_supervisor.to_rb_value(params.name, params.value, setting_data_type)

    context[:setting_db_value] = setting_db_value
    context[:setting_data_type] = setting_data_type
    context[:setting_ruby_value] = setting_ruby_value
  end

  def save_update_or_destroy(
    params:,
    existing_theme_site_setting:,
    theme:,
    setting_db_value:,
    setting_data_type:,
    setting_ruby_value:
  )
    setting_record = nil

    if existing_theme_site_setting
      # Since the site setting itself doesn't matter, if we are
      # setting this back to the same value as the default setting
      # value then it makes sense to get rid of the theme site setting
      # override.
      if params.value.nil? || setting_ruby_value == SiteSetting.defaults[params.name]
        existing_theme_site_setting.destroy!
      else
        existing_theme_site_setting.update!(value: setting_db_value)
        setting_record = existing_theme_site_setting
      end
    else
      if !params.value.nil?
        setting_record =
          theme.theme_site_settings.create!(
            name: params.name,
            value: setting_db_value,
            data_type: setting_data_type,
          )
      end
    end

    context[:theme_site_setting] = setting_record
  end

  # TODO (martin)
  #
  # Logging the change
  # Updating site setting cache?
  # Messagebus to client to update client site settings
end
