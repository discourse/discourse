# frozen_string_literal: true

class TranslationOverride < ActiveRecord::Base
  # TODO: Remove once
  # 20240711123755_drop_compiled_js_from_translation_overrides has been
  # promoted to pre-deploy
  self.ignored_columns = %w[compiled_js]

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
    %w[js.welcome_banner.header] => %w[site_name],
  }

  include HasSanitizableFields

  validates :translation_key, uniqueness: { scope: :locale }
  validates :locale, :translation_key, :value, presence: true

  validate :check_interpolation_keys
  validate :check_MF_string, if: :message_format?

  attribute :status, :integer
  enum :status, { up_to_date: 0, outdated: 1, invalid_interpolation_keys: 2, deprecated: 3 }

  scope :mf_locales,
        ->(locale) { not_deprecated.where(locale: locale).where("translation_key LIKE '%_MF'") }
  scope :client_locales,
        ->(locale) do
          not_deprecated
            .where(locale: locale)
            .where("translation_key LIKE 'js.%' OR translation_key LIKE 'admin_js.%'")
            .where.not("translation_key LIKE '%_MF'")
        end

  before_update :refresh_status

  def self.upsert!(locale, key, value)
    params = { locale: locale, translation_key: key }

    translation_override = find_or_initialize_by(params)
    sanitized_value =
      translation_override.sanitize_field(value, additional_attributes: %w[data-auto-route target])
    original_translation =
      I18n.overrides_disabled { I18n.t(transform_pluralized_key(key), locale: :en) }

    data = { value: sanitized_value, original_translation: original_translation }

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
    if key.starts_with?("post_action_types.") || key.starts_with?("topic_flag_types.")
      PostActionType.new.expire_cache
    else
      return false
    end
    true
  end

  # We use English as the source of truth when extracting interpolation keys,
  # but some languages, like Arabic, have plural forms (zero, two, few, many)
  # which don't exist in English (one, other), so we map that here in order to
  # find the correct, English translation key in which to look.
  def self.transform_pluralized_key(key)
    match = key.match(/(.*)\.(zero|two|few|many)\z/)
    match ? match.to_a.second + ".other" : key
  end

  def self.custom_interpolation_keys(translation_key)
    ALLOWED_CUSTOM_INTERPOLATION_KEYS.find do |keys, value|
      break value if keys.any? { |k| translation_key.start_with?(k) }
    end || []
  end

  private_class_method :reload_locale!
  private_class_method :clear_cached_keys!
  private_class_method :i18n_changed
  private_class_method :expire_cache

  def original_translation_deleted?
    !I18n.overrides_disabled { I18n.t!(transformed_key, locale: :en) }.is_a?(String)
  rescue I18n::MissingTranslationData
    true
  end

  def original_translation_updated?
    return false if original_translation.blank?

    original_translation != current_default
  end

  def invalid_interpolation_keys
    return [] if current_default.blank? || value.blank?

    original_interpolation_keys = I18nInterpolationKeysFinder.find(current_default)
    custom_keys = self.class.custom_interpolation_keys(transformed_key)
    allowed_keys = original_interpolation_keys + custom_keys

    # Find all patterns that look like interpolation attempts: %{...}
    attempted_keys = value.scan(/%\{([^{}]+?)\}/).flatten.uniq

    # Return keys that aren't in the allowed list
    attempted_keys - allowed_keys
  end

  def current_default
    I18n.overrides_disabled { I18n.t(transformed_key, locale: :en) }
  end

  def message_format?
    translation_key.to_s.end_with?("_MF")
  end

  def make_up_to_date!
    return unless outdated?
    self.original_translation = current_default
    update_attribute!(:status, :up_to_date)
  end

  private

  def transformed_key
    @transformed_key ||= self.class.transform_pluralized_key(translation_key)
  end

  def check_interpolation_keys
    invalid_keys = invalid_interpolation_keys

    return if invalid_keys.blank?

    self.errors.add(
      :base,
      I18n.t(
        "activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys",
        keys: invalid_keys.join(I18n.t("word_connector.comma")),
        count: invalid_keys.size,
      ),
    )
  end

  def check_MF_string
    require "messageformat"

    MessageFormat.compile(locale, { key: value }, strict: true)
  rescue MessageFormat::Compiler::CompileError => e
    errors.add(:base, e.cause.message)
  end

  def refresh_status
    self.original_translation = current_default

    self.status =
      if original_translation_deleted?
        "deprecated"
      elsif invalid_interpolation_keys.present?
        "invalid_interpolation_keys"
      elsif original_translation_updated?
        "outdated"
      else
        "up_to_date"
      end
  end
end

# == Schema Information
#
# Table name: translation_overrides
#
#  id                   :integer          not null, primary key
#  locale               :string           not null
#  translation_key      :string           not null
#  value                :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  original_translation :text
#  status               :integer          default("up_to_date"), not null
#
# Indexes
#
#  index_translation_overrides_on_locale_and_translation_key  (locale,translation_key) UNIQUE
#
