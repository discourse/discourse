# frozen_string_literal: true

module DiscourseSolved::TopicExtension
  extend ActiveSupport::Concern

  prepended { has_one :solved, class_name: "DiscourseSolved::SolvedTopic", dependent: :destroy }
end
