# frozen_string_literal: true

class SiteSettingLocalization < ActiveRecord::Base
  include LocaleMatchable

  ABOUT_CONFIG_PARAM_MAP = {
    general_settings: {
      name: "title",
      summary: "site_description",
      extended_description: "extended_site_description",
    },
  }.freeze

  class << self
    def localizable_settings
      SiteSetting.localizable_settings.deep_merge(registered_settings)
    end

    def registered_settings
      @registered_settings ||= {}
    end

    def localizable_setting_names
      localizable_settings.keys
    end

    def register(setting_name, **options)
      registered_settings[setting_name.to_s] = options.symbolize_keys
    end

    def localizable?(setting_name)
      localizable_settings.key?(setting_name.to_s) && SiteSetting.respond_to?(setting_name)
    end

    def value_for(setting_name, locale:, cooked: false, fallback: nil, show_original: false)
      fallback = SiteSetting.public_send(setting_name) if fallback.nil? &&
        SiteSetting.respond_to?(setting_name)

      return fallback if show_original
      return fallback if locale.blank?
      return fallback if !SiteSetting.content_localization_enabled?
      return fallback if !localizable?(setting_name)

      localization = lookup(setting_name, locale)
      return fallback if localization.blank?

      if cooked
        localization.cooked.presence || fallback
      else
        localization.value.presence || fallback
      end
    end

    def lookup(setting_name, locale)
      locale = normalize_locale(locale)
      scope = where(setting_name: setting_name.to_s)
      scope.find_by(locale:) || scope.matching_locale(locale).order(:locale).first
    end

    def normalize_locale(locale)
      locale.to_s.tr("-", "_")
    end

    def supported_content_locale?(locale)
      normalized_locale = normalize_locale(locale)
      return false if normalized_locale == normalize_locale(SiteSetting.default_locale)

      SiteSetting
        .content_localization_supported_locales_map
        .map { |supported_locale| normalize_locale(supported_locale) }
        .include?(normalized_locale)
    end

    def about_config_setting_names
      ABOUT_CONFIG_PARAM_MAP.values.flat_map(&:values)
    end

    def about_config_settings_from_params(params)
      ABOUT_CONFIG_PARAM_MAP.flat_map do |section_name, param_map|
        section_params = params[section_name.to_s] || params[section_name]
        next [] if section_params.blank?

        param_map.filter_map do |param_name, setting_name|
          if section_params.key?(param_name.to_s) || section_params.key?(param_name)
            value =
              if section_params.key?(param_name.to_s)
                section_params[param_name.to_s]
              else
                section_params[param_name]
              end
            { setting_name:, value: value.to_s }
          end
        end
      end
    end

    def about_config_payload(locale)
      localizations =
        where(locale:, setting_name: about_config_setting_names)
          .where.not(value: "")
          .index_by(&:setting_name)
          .transform_values do |localization|
            { value: localization.value, cooked: localization.cooked }
          end

      { locale:, localizations: }
    end
  end

  before_validation :normalize_setting_name
  before_validation :normalize_locale
  before_validation :cook_value

  validates :setting_name, presence: true
  validates :locale, presence: true, length: { maximum: 20 }
  validates :value, presence: true
  validates :setting_name, uniqueness: { scope: :locale }
  validate :setting_is_localizable
  validate :value_length_is_valid
  validate :cooked_value_is_supported

  def supports_cooked?
    self.class.localizable_settings.dig(setting_name, :cooked)
  end

  private

  def normalize_setting_name
    self.setting_name = setting_name.to_s
  end

  def normalize_locale
    self.locale = self.class.normalize_locale(locale)
  end

  def cook_value
    return if !supports_cooked?

    self.cooked = value.present? ? PrettyText.markdown(value) : nil
  end

  def setting_is_localizable
    return if self.class.localizable?(setting_name)

    errors.add(:setting_name, :inclusion)
  end

  def value_length_is_valid
    max_length = self.class.localizable_settings.dig(setting_name, :max_length)
    return if max_length.blank?
    return if value.blank? || value.length <= max_length

    errors.add(:value, :too_long, count: max_length)
  end

  def cooked_value_is_supported
    return if cooked.blank? || supports_cooked?

    errors.add(:cooked, :present)
  end
end

# == Schema Information
#
# Table name: site_setting_localizations
#
#  id                :bigint           not null, primary key
#  cooked            :text
#  locale            :string(20)       not null
#  setting_name      :string           not null
#  value             :text             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  localizer_user_id :integer
#
# Indexes
#
#  index_site_setting_localizations_on_locale                   (locale)
#  index_site_setting_localizations_on_setting_name_and_locale  (setting_name,locale) UNIQUE
#
