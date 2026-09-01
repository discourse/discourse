# frozen_string_literal: true

class ContentLocalization
  AUTOMATICALLY_TRANSLATE_COOKIE = "automatically_translate"

  # @param scope [Object] The serializer scope from which the method is called
  # @return [Boolean]
  class << self
    def automatically_translate?(scope)
      return scope.user.user_option.automatically_translate if scope&.user

      automatically_translate_anonymously?(scope&.request&.cookies)
    end

    def show_original?(scope)
      !automatically_translate?(scope)
    end

    # @param cookies [ActionDispatch::Cookies::CookieJar, Hash]
    # @return [Boolean]
    def automatically_translate_anonymously?(cookies)
      return true if cookies.blank?

      cookies[AUTOMATICALLY_TRANSLATE_COOKIE].to_s != "false"
    end

    # @param locale [String] The source locale of a topic or post
    # @param scope [Object] The serializer scope from which the method is called
    # @return [Boolean]
    def understands?(locale, scope)
      return false if locale.blank? || !scope&.user

      scope.user.user_option.understood_languages.any? do |understood_locale|
        LocaleNormalizer.is_same?(locale, understood_locale)
      end
    end

    # This method returns true when we should try to show the translated post.
    # @param scope [Object] The serializer scope from which the method is called
    # @param post [Post] The post object
    # @return [Boolean]
    def show_translated_post?(post, scope)
      SiteSetting.content_localization_enabled && post.raw.present? && post.locale.present? &&
        !post.in_user_locale? && automatically_translate?(scope) &&
        !understands?(post.locale, scope)
    end

    # This method returns true when we should try to show the translated topic.
    # @param scope [Object] The serializer scope from which the method is called
    # @param topic [Topic] The topic record
    # @return [Boolean]
    def show_translated_topic?(topic, scope)
      SiteSetting.content_localization_enabled && topic.locale.present? && !topic.in_user_locale? &&
        automatically_translate?(scope) && !understands?(topic.locale, scope)
    end

    # This method returns true when we should try to show the translated category.
    # @param category [Category] The category record
    # @param scope [Object] The serializer scope from which the method is called
    # @return [Boolean]
    def show_translated_category?(category, scope)
      SiteSetting.content_localization_enabled && category.locale.present? &&
        !category.in_user_locale?
    end

    # This method returns true when we should try to show the translated tag.
    # @param tag [Tag] The tag record
    # @param scope [Object] The serializer scope from which the method is called
    # @return [Boolean]
    def show_translated_tag?(tag, scope)
      SiteSetting.content_localization_enabled && tag.locale.present? && !tag.in_user_locale?
    end

    def show_translated_sidebar_section?(section, scope)
      SiteSetting.content_localization_enabled && section.public? && section.custom_section? &&
        section.locale.present? && !section.in_user_locale?
    end

    def show_translated_sidebar_url?(sidebar_url, scope)
      SiteSetting.content_localization_enabled && sidebar_url.locale.present? &&
        !sidebar_url.in_user_locale?
    end

    def crawler_locale_param_enabled?
      SiteSetting.content_localization_enabled && SiteSetting.content_localization_crawler_param &&
        SiteSetting.set_locale_from_param
    end

    # These are the same conditions the header renders the switcher on. Keeping the two set-equal
    # means a locale cookie is only ever honoured while there is UI to change it back.
    # @return [Boolean]
    def language_switcher_enabled?
      SiteSetting.content_localization_enabled && SiteSetting.allow_user_locale &&
        SiteSetting.content_localization_language_switcher != "none" &&
        SiteSetting.content_localization_supported_locales.present?
    end
  end
end
