# frozen_string_literal: true

class Admin::SiteTextsController < Admin::AdminController
  PREFERRED_KEYS = %w[
    education.new-reply
    education.new-topic
    login_required.welcome_message
    system_messages.usage_tips.text_body_template
  ]

  RESTRICTED_KEYS =
    Set[
      "user_notifications.confirm_old_email.title",
      "user_notifications.confirm_old_email.subject_template",
      "user_notifications.confirm_old_email.text_body_template",
      "user_notifications.confirm_old_email_add.title",
      "user_notifications.confirm_old_email_add.subject_template",
      "user_notifications.confirm_old_email_add.text_body_template"
    ].freeze

  def self.restricted_key?(key)
    RESTRICTED_KEYS.include?(key)
  end

  def index
    overridden = params[:overridden] == "true"
    outdated = params[:outdated] == "true"
    untranslated = params[:untranslated] == "true"
    only_selected_locale = params[:only_selected_locale] == "true"
    extras = {}

    query = params[:q] || ""

    locale = fetch_locale(params[:locale])

    if query.blank? && !overridden && !outdated && !untranslated
      extras[:recommended] = true
      results = PREFERRED_KEYS.map { |key| record_for(key:, locale:) }
    else
      results =
        find_translations(query, overridden, outdated, locale, untranslated, only_selected_locale)

      results.reject! { |r| RESTRICTED_KEYS.include?(r[:id]) }

      if results.any?
        extras[:regex] = I18n::Backend::DiscourseI18n.create_search_regexp(query, as_string: true)
      end

      results.sort! do |x, y|
        if x[:value].casecmp(query) == 0
          -1
        elsif y[:value].casecmp(query) == 0
          1
        else
          (x[:id].size + x[:value].size) <=> (y[:id].size + y[:value].size)
        end
      end
    end

    page = params[:page].to_i
    raise Discourse::InvalidParameters.new(:page) if page < 0

    per_page = 50
    first = page * per_page
    last = first + per_page

    extras[:has_more] = true if results.size > last

    if LocaleSiteSetting.fallback_locale(locale).present?
      extras[:fallback_locale] = LocaleSiteSetting.fallback_locale(locale)
    end

    overridden = overridden_keys(locale)
    render_serialized(
      results[first..last - 1],
      SiteTextSerializer,
      root: "site_texts",
      rest_serializer: true,
      extras:,
      overridden_keys: overridden,
    )
  end

  def show
    locale = fetch_locale(params[:locale])
    site_text = find_site_text(locale)
    render_serialized(site_text, SiteTextSerializer, root: "site_text", rest_serializer: true)
  end

  def update
    locale = fetch_locale(params.dig(:site_text, :locale))

    site_text = find_site_text(locale)
    value = site_text[:value] = params.dig(:site_text, :value)
    id = site_text[:id]
    old_value = I18n.with_locale(locale) { I18n.t(id) }

    translation_override = TranslationOverride.upsert!(locale, id, value)

    if translation_override.errors.empty?
      StaffActionLogger.new(current_user).log_site_text_change(id, value, old_value)
      system_badge_id = Badge.find_system_badge_id_from_translation_key(id)
      if system_badge_id.present? && is_badge_title?(id)
        Jobs.enqueue(
          :bulk_user_title_update,
          new_title: value,
          granted_badge_id: system_badge_id,
          action: Jobs::BulkUserTitleUpdate::UPDATE_ACTION,
        )
      end
      render_serialized(site_text, SiteTextSerializer, root: "site_text", rest_serializer: true)
    else
      render json:
               failed_json.merge(message: translation_override.errors.full_messages.join("\n\n")),
             status: :unprocessable_entity
    end
  end

  def revert
    locale = fetch_locale(params[:locale])

    site_text = find_site_text(locale)
    id = site_text[:id]
    old_text = I18n.with_locale(locale) { I18n.t(id) }
    TranslationOverride.revert!(locale, id)

    site_text = find_site_text(locale)
    StaffActionLogger.new(current_user).log_site_text_change(id, site_text[:value], old_text)
    system_badge_id = Badge.find_system_badge_id_from_translation_key(id)
    if system_badge_id.present?
      Jobs.enqueue(
        :bulk_user_title_update,
        granted_badge_id: system_badge_id,
        action: Jobs::BulkUserTitleUpdate::RESET_ACTION,
      )
    end
    render_serialized(site_text, SiteTextSerializer, root: "site_text", rest_serializer: true)
  end

  def dismiss_outdated
    locale = fetch_locale(params[:locale])
    override = TranslationOverride.find_by(locale: locale, translation_key: params[:id])

    raise Discourse::NotFound if override.blank?

    if override.make_up_to_date!
      render json: success_json
    else
      render json: failed_json.merge(message: "Can only dismiss outdated translations"),
             status: :unprocessable_entity
    end
  end

  def get_reseed_options
    render_json_dump(
      categories: SeedData::Categories.with_default_locale.reseed_options,
      topics: SeedData::Topics.with_default_locale.reseed_options,
    )
  end

  def reseed
    hijack do
      if params[:category_ids].present?
        SeedData::Categories.with_default_locale.update(site_setting_names: params[:category_ids])
      end

      if params[:topic_ids].present?
        SeedData::Topics.with_default_locale.update(site_setting_names: params[:topic_ids])
      end

      render json: success_json
    end
  end

  protected

  def is_badge_title?(id = "")
    badge_parts = id.split(".")
    badge_parts[0] == "badges" && badge_parts[2] == "name"
  end

  def record_for(key:, value: nil, locale:)
    en_key = TranslationOverride.transform_pluralized_key(key)
    value ||= I18n.with_locale(locale) { I18n.t(key) }

    interpolation_keys =
      I18nInterpolationKeysFinder.find(I18n.overrides_disabled { I18n.t(en_key, locale: :en) })
    custom_keys = TranslationOverride.custom_interpolation_keys(en_key)
    { id: key, value:, locale:, interpolation_keys: (interpolation_keys + custom_keys).sort }
  end

  PLURALIZED_REGEX = /(.*)\.(zero|one|two|few|many|other)\z/

  def find_site_text(locale)
    if RESTRICTED_KEYS.include?(params[:id])
      raise Discourse::InvalidAccess.new(
              nil,
              nil,
              custom_message: "email_template_cant_be_modified",
            )
    end

    if I18n.exists?(params[:id], locale) ||
         TranslationOverride.exists?(locale: locale, translation_key: params[:id])
      return record_for(key: params[:id], locale: locale)
    end

    if PLURALIZED_REGEX.match(params[:id])
      value = fix_plural_keys($1, {}, locale).detect { |plural| plural[0] == $2.to_sym }
      return record_for(key: params[:id], value: value[1], locale: value[2]) if value
    end

    raise Discourse::NotFound
  end

  def find_translations(query, overridden, outdated, locale, untranslated, only_selected_locale)
    translations = Hash.new { |hash, key| hash[key] = {} }
    search_results =
      I18n.with_locale(locale) do
        I18n.search(query, only_overridden: overridden, only_untranslated: untranslated)
      end

    if outdated
      outdated_keys =
        TranslationOverride.where(status: %i[outdated invalid_interpolation_keys]).pluck(
          :translation_key,
        )
      search_results.select! { |k, _| outdated_keys.include?(k) }
    end

    search_results.each do |key, value|
      if PLURALIZED_REGEX.match(key)
        translations[$1][$2] = value
      else
        translations[key] = value
      end
    end

    results = []

    translations.each do |key, value|
      next unless I18n.exists?(key, :en)

      if value.is_a?(Hash)
        fix_plural_keys(key, value, locale, only_selected_locale).each do |plural|
          plural_key = plural[0]
          plural_value = plural[1]

          results << record_for(
            key: "#{key}.#{plural_key}",
            value: plural_value,
            locale: plural.last,
          )
        end
      else
        value = I18n.with_locale(locale) { I18n.t(key) } if only_selected_locale
        results << record_for(key: key, value: value, locale: locale)
      end
    end

    results
  end

  def fix_plural_keys(key, value, locale, only_selected_locale = false)
    value = value.with_indifferent_access
    plural_keys = I18n.with_locale(locale) { I18n.t("i18n.plural.keys") }
    return value if value.keys.size == plural_keys.size && plural_keys.all? { |k| value.key?(k) }

    fallback_value = I18n.t(key, locale: :en, default: {})
    plural_keys.map do |k|
      if value[k]
        value[k] = I18n.with_locale(locale) { I18n.t("#{key}.#{k}") } if only_selected_locale
        [k, value[k], locale]
      else
        [k, fallback_value[k] || fallback_value[:other], :en]
      end
    end
  end

  def overridden_keys(locale)
    TranslationOverride.where(locale: locale).pluck(:translation_key)
  end

  def fetch_locale(locale_from_params)
    locale_from_params.tap do |locale|
      if locale.blank? || !I18n.locale_available?(locale)
        raise Discourse::InvalidParameters.new(:locale)
      end
    end
  end
end
