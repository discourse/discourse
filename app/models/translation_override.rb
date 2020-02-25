# frozen_string_literal: true

require "i18n/i18n_interpolation_keys_finder"

class TranslationOverride < ActiveRecord::Base
  # Whitelist i18n interpolation keys that can be included when customizing translations
  CUSTOM_INTERPOLATION_KEYS_WHITELIST = {
    "user_notifications.user_" => %w{
      topic_title_url_encoded
      site_title_url_encoded
      context
    }
  }

  validates_uniqueness_of :translation_key, scope: :locale
  validates_presence_of :locale, :translation_key, :value

  validate :check_interpolation_keys

  def self.upsert!(locale, key, value)
    params = { locale: locale, translation_key: key }

    data = { value: value }
    if key.end_with?('_MF')
      _, filename = JsLocaleHelper.find_message_format_locale([locale], fallback_to_english: false)
      data[:compiled_js] = JsLocaleHelper.compile_message_format(filename, locale, value)
    end

    translation_override = find_or_initialize_by(params)
    params.merge!(data) if translation_override.new_record?
    i18n_changed([key]) if translation_override.update(data)
    translation_override
  end

  def self.revert!(locale, *keys)
    TranslationOverride.where(locale: locale, translation_key: keys).delete_all
    i18n_changed(keys)
  end

  def self.i18n_changed(keys)
    I18n.reload!
    ExtraLocalesController.clear_cache!
    MessageBus.publish('/i18n-flush', refresh: true)

    keys.flatten.each do |key|
      return if expire_cache(key)
    end
  end

  def self.expire_cache(key)
    if key.starts_with?('post_action_types.')
      ApplicationSerializer.expire_cache_fragment!("post_action_types_#{I18n.locale}")
    elsif key.starts_with?('topic_flag_types.')
      ApplicationSerializer.expire_cache_fragment!("post_action_flag_types_#{I18n.locale}")
    else
      return false
    end

    Site.clear_anon_cache!
    true
  end

  private_class_method :i18n_changed
  private_class_method :expire_cache

  private

  def check_interpolation_keys
    transformed_key = transform_pluralized_key(translation_key)

    original_text = I18n.overrides_disabled do
      I18n.t(transformed_key, locale: :en)
    end

    if original_text
      original_interpolation_keys = I18nInterpolationKeysFinder.find(original_text)
      new_interpolation_keys = I18nInterpolationKeysFinder.find(value)

      custom_interpolation_keys = []

      CUSTOM_INTERPOLATION_KEYS_WHITELIST.select do |key, value|
        if transformed_key.start_with?(key)
          custom_interpolation_keys = value
        end
      end

      invalid_keys = (original_interpolation_keys | new_interpolation_keys) -
        original_interpolation_keys -
        custom_interpolation_keys

      if invalid_keys.present?
        self.errors.add(:base, I18n.t(
          'activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys',
          keys: invalid_keys.join(', ')
        ))

        false
      end
    end
  end

  def transform_pluralized_key(key)
    match = key.match(/(.*)\.(zero|two|few|many)$/)
    match ? match.to_a.second + '.other' : key
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
