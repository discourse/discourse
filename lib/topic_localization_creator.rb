# frozen_string_literal: true

class TopicLocalizationCreator
  def self.create(topic_id:, locale:, title:, user:)
    Guardian.new(user).ensure_can_localize_topic!(topic_id)

    TopicLocalization.create!(
      topic_id: topic_id,
      locale: locale,
      title: title,
      fancy_title: Topic.fancy_title(title),
      localizer_user_id: user.id,
    )
  end
end
