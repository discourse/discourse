# frozen_string_literal: true

# Topics visited grouped by tag
module DiscourseRewind
  module Action
    class MostViewedTags < BaseReport
      FakeData = {
        data: [
          { tag_id: 1, name: "cats" },
          { tag_id: 2, name: "dogs" },
          { tag_id: 3, name: "countries" },
          { tag_id: 4, name: "management" },
        ],
        identifier: "most-viewed-tags",
      }

      def call
        return FakeData if should_use_fake_data?

        most_viewed_tags =
          TopicViewItem
            .joins(:topic)
            .joins("INNER JOIN topic_tags ON topic_tags.topic_id = topics.id")
            .joins("INNER JOIN tags ON tags.id = topic_tags.tag_id")
            .where(user: user, viewed_at: date, tags: { id: Tag.visible(user.guardian).pluck(:id) })
            .group("tags.id, tags.name")
            .order("COUNT(DISTINCT topic_views.topic_id) DESC")
            .limit(4)
            .pluck("tags.id, tags.name")
            .map { |tag_id, name| { tag_id: tag_id, name: name } }

        { data: most_viewed_tags, identifier: "most-viewed-tags" }
      end
    end
  end
end
