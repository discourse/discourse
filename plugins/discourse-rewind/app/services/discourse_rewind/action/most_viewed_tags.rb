# frozen_string_literal: true

# Topics visited grouped by tag
module DiscourseRewind
  module Action
    class MostViewedTags < BaseReport
      FakeData = {
        data: [
          { tag_id: 1, slug: "cats", name: "cats" },
          { tag_id: 2, slug: "dogs", name: "dogs" },
          { tag_id: 3, slug: "countries", name: "countries" },
          { tag_id: 4, slug: "management", name: "management" },
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
            .where(user: user, viewed_at: date, tags: { id: Tag.visible(Guardian.new).pluck(:id) })
            .group("tags.id, tags.name, tags.slug")
            .order("COUNT(DISTINCT topic_views.topic_id) DESC")
            .limit(4)
            .pluck("tags.id, tags.slug, tags.name")
            .map { |tag_id, slug, name| { tag_id: tag_id, slug: slug, name: name } }

        { data: most_viewed_tags, identifier: "most-viewed-tags" }
      end
    end
  end
end
