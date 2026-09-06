# frozen_string_literal: true

class SiteSettingLocalizations::AboutConfig::Update
  include Service::Base

  params do
    attribute :locale, :string
    attribute :general_settings, default: -> { {} }

    before_validation { self.locale = SiteSettingLocalization.normalize_locale(locale) }

    validates :locale, presence: true
  end

  policy :can_localize_site_settings
  policy :locale_is_supported
  step :extract_submitted_settings

  transaction do
    each :submitted_settings, as: :submitted_setting do
      step :save_submitted_setting
    end
  end

  only_if(:submitted_settings_present) { step :log_update }

  step :build_payload

  private

  def can_localize_site_settings(guardian:)
    guardian.can_localize_site_settings?
  end

  def locale_is_supported(params:)
    SiteSettingLocalization.supported_content_locale?(params.locale)
  end

  def extract_submitted_settings(params:)
    context[:submitted_settings] = SiteSettingLocalization.about_config_settings_from_params(
      params.raw_attributes,
    )
  end

  def save_submitted_setting(guardian:, params:, submitted_setting:)
    if submitted_setting[:value].blank?
      SiteSettingLocalization.where(
        setting_name: submitted_setting[:setting_name],
        locale: params.locale,
      ).destroy_all
    else
      localization =
        SiteSettingLocalization.find_or_initialize_by(
          setting_name: submitted_setting[:setting_name],
          locale: params.locale,
        )
      localization.value = submitted_setting[:value]
      localization.localizer_user_id = guardian.user.id
      localization.save!
    end
  end

  def submitted_settings_present(submitted_settings:)
    submitted_settings.present?
  end

  def log_update(guardian:, params:, submitted_settings:)
    StaffActionLogger.new(guardian.user).log_update_site_setting_localizations(
      locale: params.locale,
      setting_names: submitted_settings.map { |setting| setting[:setting_name] },
    )
  end

  def build_payload(params:)
    context[:payload] = SiteSettingLocalization.about_config_payload(params.locale)
  end
end
