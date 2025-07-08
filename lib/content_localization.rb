# frozen_string_literal: true

class ContentLocalization
  SHOW_ORIGINAL_COOKIE = "content-localization-show-original"

  # @param scope [Object] The serializer scope from which the method is called
  # @return [Boolean] if the cookie is set, false otherwise
  def self.show_original?(scope)
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
end
