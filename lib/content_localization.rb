# frozen_string_literal: true

class ContentLocalization
  SHOW_ORIGINAL_COOKIE = "content-localization-show-original"

  def self.show_original?(scope)
    scope&.request&.cookies&.key?(SHOW_ORIGINAL_COOKIE)
  end

  def self.show_translated_post?(post, scope)
    SiteSetting.experimental_content_localization && post.locale.present? &&
      !post.in_user_locale? && !show_original?(scope)
  end
end
