# frozen_string_literal: true

module DiscourseRewind
  module Action
    class BestTopics < BaseReport
      FakeData = {
        data: [
          {
            topic_id: 1,
            title: "How to get started with Rails",
            excerpt: "A comprehensive guide to getting started with Ruby on Rails...",
          },
          {
            topic_id: 2,
            title: ":file_cabinet: Best practices for database optimization",
            excerpt: "Learn how to optimize your database queries for better performance...",
          },
          {
            topic_id: 3,
            title: "Understanding ActiveRecord associations",
            excerpt: "Deep dive into has_many, belongs_to, and other associations...",
          },
        ],
        identifier: "best-topics",
      }

      def call
        return FakeData if should_use_fake_data?

        best_topics =
          TopTopic
            .joins(:topic)
            .merge(self.class.publicly_visible_topics)
            .where(topics: { created_at: date, user_id: user.id })
            .order("yearly_score DESC NULLS LAST, top_topics.topic_id")
            .limit(3)
            .pluck(:topic_id, :title, :excerpt)
            .map { |topic_id, title, excerpt| { topic_id:, title:, excerpt: } }

        { data: best_topics, identifier: "best-topics" }
      end

      def self.filter_for_viewer(report, guardian:, **)
        topic_ids = guardian.can_see_topic_ids(topic_ids: report[:data].pluck(:topic_id))
        eligible_topic_ids = publicly_visible_topics.where(id: topic_ids).pluck(:id)

        report.merge(
          data: report[:data].select { |topic| topic[:topic_id].in?(eligible_topic_ids) },
        )
      end
    end
  end
end
