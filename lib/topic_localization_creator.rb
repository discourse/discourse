# frozen_string_literal: true

class TopicLocalizationCreator
  def self.create(topic:, locale:, title:, user:)
    Guardian.new(user).ensure_can_localize_topic!(topic)

    excerpt = nil
    first_post = topic.first_post
    if first_post
      post_localization = first_post.localizations.find_by(locale:)
      if post_localization
        excerpt =
          Post.excerpt(
            post_localization.cooked,
            SiteSetting.topic_excerpt_maxlength,
            strip_links: true,
            strip_images: true,
          )
      end
    end

    TopicLocalization.create!(
      topic_id: topic.id,
      locale: locale,
      title: title,
      fancy_title: Topic.fancy_title(title),
      localizer_user_id: user.id,
      excerpt: excerpt,
    )
  end
end
