# frozen_string_literal: true

class TranslationOverride < ActiveRecord::Base
  # Allowlist i18n interpolation keys that can be included when customizing translations
  ALLOWED_CUSTOM_INTERPOLATION_KEYS = {
    %w[
      user_notifications.user_
      user_notifications.only_reply_by_email
      user_notifications.reply_by_email
      user_notifications.visit_link_to_respond
      user_notifications.header_instructions
      user_notifications.pm_participants
      unsubscribe_mailing_list
      unsubscribe_link_and_mail
      unsubscribe_link
    ] => %w[
      topic_title
      topic_title_url_encoded
      message
      url
      post_id
      topic_id
      context
      username
      group_name
      unsubscribe_url
      subject_pm
      participants
      site_description
      site_title
      site_title_url_encoded
      site_name
      optional_re
      optional_pm
      optional_cat
      optional_tags
    ],
    %w[system_messages.welcome_user] => %w[username name name_or_username],
  }

  include HasSanitizableFields
  include ActiveSupport::Deprecation::DeprecatedConstantAccessor
  deprecate_constant "CUSTOM_INTERPOLATION_KEYS_WHITELIST",
                     "TranslationOverride::ALLOWED_CUSTOM_INTERPOLATION_KEYS"

  validates_uniqueness_of :translation_key, scope: :locale
  validates_presence_of :locale, :translation_key, :value

  validate :check_interpolation_keys

  def self.upsert!(locale, key, value)
    params = { locale: locale, translation_key: key }

    translation_override = find_or_initialize_by(params)
    sanitized_value =
      translation_override.sanitize_field(value, additional_attributes: ["data-auto-route"])

    data = { value: sanitized_value }
    if key.end_with?("_MF")
      _, filename = JsLocaleHelper.find_message_format_locale([locale], fallback_to_english: false)
      data[:compiled_js] = JsLocaleHelper.compile_message_format(filename, locale, sanitized_value)
    end

    params.merge!(data) if translation_override.new_record?
    i18n_changed(locale, [key]) if translation_override.update(data)
    translation_override
  end

  def self.revert!(locale, keys)
    keys = Array.wrap(keys)
    TranslationOverride.where(locale: locale, translation_key: keys).delete_all
    i18n_changed(locale, keys)
  end

  def self.reload_all_overrides!
    reload_locale!

    overrides = TranslationOverride.pluck(:locale, :translation_key)
    overrides = overrides.group_by(&:first).map { |k, a| [k, a.map(&:last)] }
    overrides.each { |locale, keys| clear_cached_keys!(locale, keys) }
  end

  def self.reload_locale!
    I18n.reload!
    ExtraLocalesController.clear_cache!
    MessageBus.publish("/i18n-flush", refresh: true)
  end

  def self.clear_cached_keys!(locale, keys)
    should_clear_anon_cache = false
    keys.each { |key| should_clear_anon_cache |= expire_cache(locale, key) }
    Site.clear_anon_cache! if should_clear_anon_cache
  end

  def self.i18n_changed(locale, keys)
    reload_locale!
    clear_cached_keys!(locale, keys)
  end

  def self.expire_cache(locale, key)
    if key.starts_with?("post_action_types.")
      ApplicationSerializer.expire_cache_fragment!("post_action_types_#{locale}")
    elsif key.starts_with?("topic_flag_types.")
      ApplicationSerializer.expire_cache_fragment!("post_action_flag_types_#{locale}")
    else
      return false
    end
    true
  end

  private_class_method :reload_locale!
  private_class_method :clear_cached_keys!
  private_class_method :i18n_changed
  private_class_method :expire_cache

  private

  def check_interpolation_keys
    transformed_key = transform_pluralized_key(translation_key)

    original_text = I18n.overrides_disabled { I18n.t(transformed_key, locale: :en) }

    if original_text
      original_interpolation_keys = I18nInterpolationKeysFinder.find(original_text)
      new_interpolation_keys = I18nInterpolationKeysFinder.find(value)
      custom_interpolation_keys = []

      ALLOWED_CUSTOM_INTERPOLATION_KEYS.select do |keys, value|
        custom_interpolation_keys = value if keys.any? { |key| transformed_key.start_with?(key) }
      end

      invalid_keys =
        (original_interpolation_keys | new_interpolation_keys) - original_interpolation_keys -
          custom_interpolation_keys

      if invalid_keys.present?
        self.errors.add(
          :base,
          I18n.t(
            "activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys",
            keys: invalid_keys.join(I18n.t("word_connector.comma")),
            count: invalid_keys.size,
          ),
        )

        false
      end
    end
  end

  def transform_pluralized_key(key)
    match = key.match(/(.*)\.(zero|two|few|many)\z/)
    match ? match.to_a.second + ".other" : key
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
