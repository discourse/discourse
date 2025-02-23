# frozen_string_literal: true

class SiteSetting::Update
  include Service::Base

  options { attribute :allow_changing_hidden, :array, default: [] }

  policy :current_user_is_admin

  params do
    attribute :settings

    before_validation do
      self.settings = self.settings.to_a.map { |key, value| [key.to_sym, value.to_s.strip] }.to_h
    end

    validates :settings, presence: true

    after_validation do
      self.settings =
        self
          .settings
          .map do |setting_name, value|
            value =
              case SiteSetting.type_supervisor.get_type(setting_name)
              when :integer
                value.tr("^-0-9", "").to_i
              when :file_size_restriction
                value.tr("^0-9", "").to_i
              when :uploaded_image_list
                value.blank? ? "" : Upload.get_from_urls(value.split("|")).to_a
              when :upload
                Upload.get_from_url(value) || ""
              else
                value
              end
            [setting_name, value]
          end
          .to_h
    end
  end

  policy :settings_are_unshadowed_globally,
         class_name: SiteSetting::Policy::SettingsAreUnshadowedGlobally
  policy :settings_are_visible, class_name: SiteSetting::Policy::SettingsAreVisible
  policy :settings_are_configurable, class_name: SiteSetting::Policy::SettingsAreConfigurable
  policy :values_are_valid, class_name: SiteSetting::Policy::ValuesAreValid
  transaction { step :save }

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def save(params:, guardian:)
    params.settings.each do |setting_name, value|
      SiteSetting.set_and_log(setting_name, value, guardian.user)
    end
  end
end
