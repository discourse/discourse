require 'js_locale_helper'

class TranslationOverride < ActiveRecord::Base
  validates_uniqueness_of :translation_key, scope: :locale
  validates_presence_of :locale, :translation_key, :value

  def self.upsert!(locale, key, value)
    params = { locale: locale, translation_key: key }

    data = { value: value }
    if key.end_with?('_MF')
      data[:compiled_js] = JsLocaleHelper.compile_message_format(locale, value)
    end

    row_count = where(params).update_all(data)
    create!(params.merge(data)) if row_count == 0
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

# == Schema Information
#
# Table name: translation_overrides
#
#  id              :integer          not null, primary key
#  locale          :string           not null
#  translation_key :string           not null
#  value           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  compiled_js     :text
#
# Indexes
#
#  index_translation_overrides_on_locale_and_translation_key  (locale,translation_key) UNIQUE
#
