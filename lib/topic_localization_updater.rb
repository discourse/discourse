# frozen_string_literal: true

class TopicLocalizationUpdater
  def self.update(topic:, locale:, title:, user:)
    Guardian.new(user).ensure_can_localize_topic!(topic)

    localization = TopicLocalization.find_by(topic_id: topic.id, locale: locale)
    raise Discourse::NotFound unless localization

    return localization if localization.title == title

    localization.title = title
    localization.fancy_title = Topic.fancy_title(title)
    localization.localizer_user_id = user.id
    localization.save!
    localization
  end
end
