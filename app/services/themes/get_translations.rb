# frozen_string_literal: true

# Gets all of the translation overrides for a theme, which are defined
# in locale yml files for a theme. A ThemeField is created for each locale,
# which in turn creates ThemeTranslationOverride records.
#
# @example
#  Themes::GetTranslations.call(
#    guardian: guardian,
#    params: {
#      id: theme.id,
#      locale: "en",
#    }
#  )
#
class Themes::GetTranslations
  include Service::Base

  params do
    attribute :locale, :string
    attribute :id, :integer

    validates :id, presence: true
    validates :locale, presence: true

    validate :validate_locale, if: -> { locale.present? }

    def validate_locale
      return if I18n.available_locales.include?(locale.to_sym)
      errors.add(:base, I18n.t("errors.messages.invalid_locale", invalid_locale: locale))
    end
  end

  model :theme
  model :translations

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.id)
  end

  def fetch_translations(theme:, params:)
    I18n.with_locale(params.locale) do
      theme.translations.map do |translation|
        { key: translation.key, value: translation.value, default: translation.default }
      end
    end
  end
end
