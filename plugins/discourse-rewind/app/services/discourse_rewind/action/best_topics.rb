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
            yearly_score: 42.5,
          },
          {
            topic_id: 2,
            title: ":file_cabinet: Best practices for database optimization",
            excerpt: "Learn how to optimize your database queries for better performance...",
            yearly_score: 38.2,
          },
          {
            topic_id: 3,
            title: "Understanding ActiveRecord associations",
            excerpt: "Deep dive into has_many, belongs_to, and other associations...",
            yearly_score: 35.7,
          },
        ],
        identifier: "best-topics",
      }

      def call
        return FakeData if should_use_fake_data?

        best_topics =
          TopTopic
            .includes(:topic)
            .references(:topic)
            .joins(topic: :category)
            .where(topic: { deleted_at: nil, created_at: date, user_id: user.id })
            .where.not(topic: { archetype: Archetype.private_message })
            .where("NOT categories.read_restricted")
            .order("yearly_score DESC NULLS LAST")
            .limit(3)
            .pluck(:topic_id, :title, :excerpt, :yearly_score)
            .map do |topic_id, title, excerpt, yearly_score|
              { topic_id: topic_id, title: title, excerpt: excerpt, yearly_score: yearly_score }
            end

        { data: best_topics, identifier: "best-topics" }
      end
    end
  end
end
