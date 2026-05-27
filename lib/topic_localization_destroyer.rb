# frozen_string_literal: true

class TopicLocalizationDestroyer
  def self.destroy(topic:, locale:, acting_user:)
    Guardian.new(acting_user).ensure_can_localize_topic!(topic)

    localization = TopicLocalization.find_by(topic_id: topic.id, locale: locale)
    raise Discourse::NotFound unless localization

    localization.destroy
  end
end
