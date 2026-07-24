# frozen_string_literal: true

module DiscourseSolved
  class SolvedTopic < ActiveRecord::Base
    self.table_name = "discourse_solved_solved_topics"

    # TODO: Remove these columns fully in a future migration
    self.ignored_columns += %i[answer_post_id accepter_user_id]

    belongs_to :topic, class_name: "Topic"
    has_many :topic_answers, class_name: "DiscourseSolved::TopicAnswer", dependent: :destroy
    has_many :answer_posts, through: :topic_answers, class_name: "Post", source: :post
    belongs_to :topic_timer, dependent: :destroy

    validates :topic_id, presence: true

    before_create :auto_close_topic_timer

    private

    def auto_close_topic_timer
      hours = topic.solved_auto_close_hours
      return if hours.zero? || topic.closed?

      self.topic_timer =
        topic.set_or_create_timer(
          TopicTimer.types[:silent_close],
          nil,
          based_on_last_post: true,
          duration_minutes: hours * 60,
        )
    end
  end
end

# == Schema Information
#
# Table name: discourse_solved_solved_topics
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  topic_id       :bigint           not null
#  topic_timer_id :integer
#
# Indexes
#
#  index_discourse_solved_solved_topics_on_answer_post_id  (answer_post_id) UNIQUE
#  index_discourse_solved_solved_topics_on_topic_id        (topic_id) UNIQUE
#
