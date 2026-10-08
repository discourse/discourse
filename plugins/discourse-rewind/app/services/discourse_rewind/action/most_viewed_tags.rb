# frozen_string_literal: true

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
            .joins(topic: :tags)
            .merge(Topic.listable_topics.secured)
            .where(user:, viewed_at: date, tags: { id: self.class.public_tags.select(:id) })
            .group("tags.id, tags.name, tags.slug")
            .order("COUNT(DISTINCT topic_views.topic_id) DESC, tags.id")
            .limit(4)
            .pluck("tags.id, tags.slug, tags.name")
            .map { |tag_id, slug, name| { tag_id:, slug:, name: } }

        { data: most_viewed_tags, identifier: "most-viewed-tags" }
      end

      def self.public_tags
        Tag.visible(Guardian.new)
      end

      def self.filter_for_viewer(report, **)
        visible_tag_ids = public_tags.where(id: report[:data].pluck(:tag_id)).pluck(:id)

        report.merge(data: report[:data].select { |tag| tag[:tag_id].in?(visible_tag_ids) })
      end
    end
  end
end
