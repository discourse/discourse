# frozen_string_literal: true

module DiscourseSolved::TopicExtension
  extend ActiveSupport::Concern

  prepended do
    has_one :solved, class_name: "DiscourseSolved::SolvedTopic", dependent: :destroy
    has_many :shared_issues,
             class_name: "DiscourseSolved::SharedIssue",
             foreign_key: :topic_id,
             dependent: :delete_all
  end

  def solved_auto_close_hours
    hours = category&.solved_auto_close_hours || 0
    hours.zero? ? SiteSetting.solved_topics_auto_close_hours : hours
  end

  def topic_answers
    solved&.topic_answers || DiscourseSolved::TopicAnswer.none
  end
end
