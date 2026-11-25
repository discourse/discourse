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
            .where(topic: { deleted_at: nil, created_at: date, user_id: user.id, visible: true })
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
<<<<<<< HEAD
=======

      def self.filter_for_viewer(report, guardian:, **)
        topic_ids = guardian.can_see_topic_ids(topic_ids: report[:data].pluck(:topic_id))
        hidden_topic_ids = Post.where(topic_id: topic_ids, post_number: 1, hidden: true)
        eligible_topic_ids =
          publicly_visible_topics
            .where(id: topic_ids)
            .where.not(id: hidden_topic_ids.select(:topic_id))
            .pluck(:id)

        report.merge(
          data: report[:data].select { |topic| topic[:topic_id].in?(eligible_topic_ids) },
        )
      end
>>>>>>> de267ee957 (SECURITY: Prevent hidden first-post content from leaking through cached topic list excerpts (#46698))
    end
  end
end
