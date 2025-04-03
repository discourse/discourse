# frozen_string_literal: true

class SiteSetting::Update
  include Service::Base

  Setting = Struct.new(:name, :value, :backfill, :change)

  options do
    attribute :allow_changing_hidden, :array, default: []
    attribute :overridden_setting_names, default: {}
  end

  policy :current_user_is_admin

  params do
    attribute :settings

    before_validation do
      self.settings =
        self.settings.to_a.map do |setting|
          Setting.new(
            setting[:setting_name].to_sym,
            setting[:value].to_s.strip,
            !!setting[:backfill],
            nil,
          )
        end
    end

    validates :settings, presence: true

    after_validation do
      self.settings =
        self.settings.map do |setting|
          raw_value = setting.value

          setting.value =
            case SiteSetting.type_supervisor.get_type(setting.name)
            when :integer
              raw_value.tr("^-0-9", "").to_i
            when :file_size_restriction
              raw_value.tr("^0-9", "").to_i
            when :uploaded_image_list
              raw_value.blank? ? "" : Upload.get_from_urls(raw_value.split("|")).to_a
            when :upload
              Upload.get_from_url(raw_value) || ""
            else
              raw_value
            end

          setting
        end
    end
  end

  policy :settings_are_not_deprecated, class_name: SiteSetting::Policy::SettingsAreNotDeprecated
  policy :settings_are_unshadowed_globally,
         class_name: SiteSetting::Policy::SettingsAreUnshadowedGlobally
  policy :settings_are_visible, class_name: SiteSetting::Policy::SettingsAreVisible
  policy :settings_are_configurable, class_name: SiteSetting::Policy::SettingsAreConfigurable
  policy :values_are_valid, class_name: SiteSetting::Policy::ValuesAreValid

  transaction do
    step :save
    step :backfill
  end

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def save(params:, options:, guardian:)
    params.settings.each do |setting|
      setting.change =
        SiteSetting.set_and_log(
          options.overridden_setting_names[setting.name] || setting.name,
          setting.value,
          guardian.user,
        )
    end
  end

  def backfill(params:)
    params.settings.each do |setting|
      next if !setting.backfill || !default_user_preference?(setting)

      SiteSettingUpdateExistingUsers.call(
        setting.name.to_s,
        setting.change.new_value,
        setting.change.previous_value,
      )
    end
  end

  def default_user_preference?(setting)
    SiteSetting::DEFAULT_USER_PREFERENCES.include?(setting.name.to_s)
  end
end
