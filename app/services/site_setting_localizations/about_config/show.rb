# frozen_string_literal: true

class SiteSettingLocalizations::AboutConfig::Show
  include Service::Base

  params do
    attribute :locale, :string

    before_validation { self.locale = SiteSettingLocalization.normalize_locale(locale) }

    validates :locale, presence: true
  end

  policy :can_localize_site_settings
  policy :locale_is_supported
  step :build_payload

  private

  def can_localize_site_settings(guardian:)
    guardian.can_localize_site_settings?
  end

  def locale_is_supported(params:)
    SiteSettingLocalization.supported_content_locale?(params.locale)
  end

  def build_payload(params:)
    context[:payload] = SiteSettingLocalization.about_config_payload(params.locale)
  end
end
