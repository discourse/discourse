# frozen_string_literal: true

class ContentLocalization
  SHOW_ORIGINAL_COOKIE = "content-localization-show-original"

  # @param scope [Object] The serializer scope from which the method is called
  # @return [Boolean] if the cookie is set, false otherwise
  def self.show_original?(scope)
    return true if scope&.user&.user_option&.show_original_content
    return false if scope&.user
    scope&.request&.cookies&.key?(SHOW_ORIGINAL_COOKIE)
  end

  # This method returns true when we should try to show the translated post.
  # @param scope [Object] The serializer scope from which the method is called
  # @param post [Post] The post object
  # @return [Boolean]
  def self.show_translated_post?(post, scope)
    SiteSetting.content_localization_enabled && post.raw.present? && post.locale.present? &&
      !post.in_user_locale? && !show_original?(scope)
  end

  # This method returns true when we should try to show the translated topic.
  # @param scope [Object] The serializer scope from which the method is called
  # @param topic [Topic] The topic record
  # @return [Boolean]
  def self.show_translated_topic?(topic, scope)
    SiteSetting.content_localization_enabled && topic.locale.present? && !topic.in_user_locale? &&
      !show_original?(scope)
  end

  # This method returns true when we should try to show the translated category.
  # @param category [Category] The category record
  # @param scope [Object] The serializer scope from which the method is called
  # @return [Boolean]
  def self.show_translated_category?(category, scope)
    SiteSetting.content_localization_enabled && category.locale.present? &&
      !category.in_user_locale?
  end

  # This method returns true when we should try to show the translated tag.
  # @param tag [Tag] The tag record
  # @param scope [Object] The serializer scope from which the method is called
  # @return [Boolean]
  def self.show_translated_tag?(tag, scope)
    SiteSetting.content_localization_enabled && tag.locale.present? && !tag.in_user_locale?
  end

  def self.show_translated_sidebar_section?(section, scope)
    SiteSetting.content_localization_enabled && section.public? && section.custom_section? &&
      section.locale.present? && !section.in_user_locale?
  end

  def self.show_translated_sidebar_url?(sidebar_url, scope)
    SiteSetting.content_localization_enabled && sidebar_url.locale.present? &&
      !sidebar_url.in_user_locale?
  end

  def self.crawler_locale_param_enabled?
    SiteSetting.content_localization_enabled && SiteSetting.content_localization_crawler_param &&
      SiteSetting.set_locale_from_param
  end
end
