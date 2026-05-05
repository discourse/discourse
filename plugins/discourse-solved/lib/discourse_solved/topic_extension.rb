# frozen_string_literal: true

module DiscourseSolved::TopicExtension
  extend ActiveSupport::Concern

  prepended { has_one :solved, class_name: "DiscourseSolved::SolvedTopic", dependent: :destroy }

  def solved_auto_close_hours
    hours = category&.solved_auto_close_hours || 0
    hours.zero? ? SiteSetting.solved_topics_auto_close_hours : hours
  end
end
