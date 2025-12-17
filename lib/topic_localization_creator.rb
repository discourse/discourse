# frozen_string_literal: true

class TopicLocalizationCreator
  def self.create(topic:, locale:, title:, user:)
    Guardian.new(user).ensure_can_localize_topic!(topic)

    TopicLocalization.create!(
      topic_id: topic.id,
      locale: locale,
      title: title,
      fancy_title: Topic.fancy_title(title),
      localizer_user_id: user.id,
    )
  end
end
