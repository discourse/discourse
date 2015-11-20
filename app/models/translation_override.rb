class TranslationOverride < ActiveRecord::Base
  validates_uniqueness_of :translation_key, scope: :locale
  validates_presence_of :locale, :translation_key, :value

  def self.upsert!(locale, key, value)
    params = { locale: locale, translation_key: key }
    row_count = where(params).update_all(value: value)
    create!(params.merge(value: value)) if row_count == 0
    i18n_changed
  end

  def self.revert!(locale, *keys)
    TranslationOverride.where(locale: locale, translation_key: keys).delete_all
    i18n_changed
  end

  protected

    def self.i18n_changed
      I18n.reload!
      MessageBus.publish('/i18n-flush', { refresh: true })
    end

end
