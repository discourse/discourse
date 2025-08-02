# frozen_string_literal: true

class TopicLocalizationCreator
  def self.create(topic_id:, locale:, title:, user:)
    Guardian.new(user).ensure_can_localize_content!

    topic = Topic.find_by(id: topic_id)
    raise Discourse::NotFound unless topic

    TopicLocalization.create!(
      topic_id: topic.id,
      locale: locale,
      title: title,
      fancy_title: Topic.fancy_title(title),
      localizer_user_id: user.id,
    )
  end
end
