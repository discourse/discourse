# frozen_string_literal: true

require_dependency 'seed_data/categories'
require_dependency 'seed_data/topics'

class Admin::SiteTextsController < Admin::AdminController

  def self.preferred_keys
    ['system_messages.usage_tips.text_body_template',
     'education.new-topic',
     'education.new-reply',
     'login_required.welcome_message']
  end

  def self.restricted_keys
    ['user_notifications.confirm_old_email.title',
     'user_notifications.confirm_old_email.subject_template',
     'user_notifications.confirm_old_email.text_body_template']
  end

  def index
    overridden = params[:overridden] == 'true'
    extras = {}

    query = params[:q] || ""
    if query.blank? && !overridden
      extras[:recommended] = true
      results = self.class.preferred_keys.map { |k| record_for(k) }
    else
      results = find_translations(query, overridden)

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

    extras[:has_more] = true if results.size > 50
    render_serialized(results[0..49], SiteTextSerializer, root: 'site_texts', rest_serializer: true, extras: extras, overridden_keys: overridden_keys)
  end

  def show
    site_text = find_site_text
    render_serialized(site_text, SiteTextSerializer, root: 'site_text', rest_serializer: true)
  end

  def update
    site_text = find_site_text
    value = site_text[:value] = params[:site_text][:value]
    id = site_text[:id]
    old_value = I18n.t(id)
    translation_override = TranslationOverride.upsert!(I18n.locale, id, value)

    if translation_override.errors.empty?
      StaffActionLogger.new(current_user).log_site_text_change(id, value, old_value)
      render_serialized(site_text, SiteTextSerializer, root: 'site_text', rest_serializer: true)
    else
      render json: failed_json.merge(
        message: translation_override.errors.full_messages.join("\n\n")
      ), status: 422
    end
  end

  def revert
    site_text = find_site_text
    old_text = I18n.t(site_text[:id])
    TranslationOverride.revert!(I18n.locale, site_text[:id])
    site_text = find_site_text
    StaffActionLogger.new(current_user).log_site_text_change(site_text[:id], site_text[:value], old_text)
    render_serialized(site_text, SiteTextSerializer, root: 'site_text', rest_serializer: true)
  end

  def get_reseed_options
    render_json_dump(
      categories: SeedData::Categories.with_default_locale.reseed_options,
      topics: SeedData::Topics.with_default_locale.reseed_options
    )
  end

  def reseed
    hijack do
      if params[:category_ids].present?
        SeedData::Categories.with_default_locale.update(
          site_setting_names: params[:category_ids]
        )
      end

      if params[:topic_ids].present?
        SeedData::Topics.with_default_locale.update(
          site_setting_names: params[:topic_ids]
        )
      end

      render json: success_json
    end
  end

  protected

  def record_for(key, value = nil)
    if key.ends_with?("_MF")
      override = TranslationOverride.where(translation_key: key, locale: I18n.locale).pluck(:value)
      value = override&.first
    end

    value ||= I18n.t(key, default: '')
    { id: key, value: value }
  end

  PLURALIZED_REGEX = /(.*)\.(zero|one|two|few|many|other)$/

  def find_site_text
    if self.class.restricted_keys.include?(params[:id])
      raise Discourse::InvalidAccess.new(nil, nil, custom_message: 'email_template_cant_be_modified')
    end

    if I18n.exists?(params[:id]) || TranslationOverride.exists?(locale: I18n.locale, translation_key: params[:id])
      return record_for(params[:id])
    end

    if PLURALIZED_REGEX.match(params[:id])
      value = fix_plural_keys($1, {}).fetch($2.to_sym)
      return record_for(params[:id], value) if value
    end

    raise Discourse::NotFound
  end

  def find_translations(query, overridden)
    translations = Hash.new { |hash, key| hash[key] = {} }

    I18n.search(query, overridden: overridden).each do |key, value|
      if PLURALIZED_REGEX.match(key)
        translations[$1][$2] = value
      else
        translations[key] = value
      end
    end

    results = []

    translations.each do |key, value|
      next unless I18n.exists?(key, :en)

      if value&.is_a?(Hash)
        value = fix_plural_keys(key, value)
        value.each do |plural_key, plural_value|
          results << record_for("#{key}.#{plural_key}", plural_value)
        end
      else
        results << record_for(key, value)
      end
    end

    results
  end

  def fix_plural_keys(key, value)
    value = value.with_indifferent_access
    plural_keys = I18n.t('i18n.plural.keys')
    return value if value.keys.size == plural_keys.size && plural_keys.all? { |k| value.key?(k) }

    fallback_value = I18n.t(key, locale: :en, default: {})
    plural_keys.map do |k|
      [k, value[k] || fallback_value[k] || fallback_value[:other]]
    end.to_h
  end

  def overridden_keys
    TranslationOverride.where(locale: I18n.locale).pluck(:translation_key)
  end
end
