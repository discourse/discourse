# frozen_string_literal: true

class PostLocaleUpdater
  def self.update(post:, locale:, user:)
    Guardian.new(user).ensure_can_localize_post!(post)
    validate_locale!(locale)

    post.update!(locale:)
    post
  end

  def self.validate_locale!(locale)
    return if locale.nil? || LocaleSiteSetting.supported_locales.include?(locale)

    raise Discourse::InvalidParameters.new(:locale)
  end
  private_class_method :validate_locale!
end
