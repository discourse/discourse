# frozen_string_literal: true

class Themes::GetTranslations
  include Service::Base

  params do
    attribute :locale, :string
    attribute :id, :integer

    validates :id, presence: true
    validates :locale, presence: true
  end

  policy :validate_locale
  step :set_i18n_locale
  model :theme
  step :get_translations

  private

  def validate_locale(params:)
    I18n.available_locales.include?(params.locale.to_sym)
  end

  def set_i18n_locale(params:)
    I18n.locale = params.locale
  end

  def fetch_theme(params:)
    Theme.find_by(id: params.id)
  end

  def get_translations(theme:)
    context[:translations] = theme.translations.map do |translation|
      { key: translation.key, value: translation.value, default: translation.default }
    end
  end
end
