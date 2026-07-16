# frozen_string_literal: true

class TopicLocaleUpdater
  def self.update(topic:, locale:, user:)
    Guardian.new(user).ensure_can_localize_topic!(topic)
    validate_locale!(locale)

    topic.update!(locale:)
    topic
  end

  def self.validate_locale!(locale)
    return if locale.nil? || LocaleSiteSetting.supported_locales.include?(locale)

    raise Discourse::InvalidParameters.new(:locale)
  end
  private_class_method :validate_locale!
end
