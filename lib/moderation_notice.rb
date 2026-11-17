# frozen_string_literal: true

class ModerationNotice
  def initialize(automated_detection:)
    @automated_detection = automated_detection
  end

  def message_options(recipient:, message_type:, post_action_type_id:)
    locale = recipient.effective_locale
    message_type = message_type.to_s
    base_key = "system_messages.#{message_type}"
    variant = @automated_detection ? "automated" : "moderator"
    key = "#{base_key}.#{variant}"
    options = {}

    if @automated_detection
      flag_type = PostActionType.flag_types[post_action_type_id]
      suffix = ".responder" if message_type == "flags_agreed_and_post_deleted_for_responders"
      reason_key = "flag_reasons.automated#{suffix}.#{flag_type}"
      base_reason_key = "flag_reasons#{suffix}.#{flag_type}"
      reason_locale = SiteSetting.default_locale
      if compatible_template?(key: reason_key, base_key: base_reason_key, locale: reason_locale) &&
           !overridden?(key: base_reason_key, locale: reason_locale)
        options[:flag_reason] = I18n.t(
          reason_key,
          locale: reason_locale,
          base_path: Discourse.base_path,
        )
      end
    end

    body_key = "#{key}.text_body_template"
    base_body_key = "#{base_key}.text_body_template"
    if compatible_template?(key: body_key, base_key: base_body_key, locale:) &&
         !overridden?(key: base_body_key, locale:)
      options[:body_template_key] = body_key
    end

    title_key = "#{key}.subject_template"
    base_title_key = "#{base_key}.subject_template"
    if compatible_template?(key: title_key, base_key: base_title_key, locale:) &&
         !overridden?(key: base_title_key, locale:)
      options[:title_template_key] = title_key
    end

    options
  end

  private

  def compatible_template?(key:, base_key:, locale:)
    template_locale = translation_locale(key:, locale:)
    base_locale = translation_locale(key: base_key, locale:)
    return false unless template_locale && base_locale

    fallbacks = I18n.fallbacks[locale]
    fallbacks.index(template_locale) <= fallbacks.index(base_locale)
  end

  def translation_locale(key:, locale:)
    I18n.fallbacks[locale].find do |fallback|
      overrides = I18n.overrides_by_locale(fallback)
      I18n.ensure_loaded!(fallback)
      overrides.key?(key) || I18n.backend.exists?(fallback, key, fallback: false)
    end
  end

  def overridden?(key:, locale:)
    source_locale = translation_locale(key:, locale:)
    return false unless source_locale

    I18n.overrides_by_locale(source_locale).key?(key)
  end
end
