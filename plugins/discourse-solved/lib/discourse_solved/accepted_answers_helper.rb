# frozen_string_literal: true

module DiscourseSolved
  module AcceptedAnswersHelper
    def self.serialize(topic, guardian)
      solved = topic.solved
      return [] unless solved&.topic_answers&.any?

      ActiveRecord::Associations::Preloader.new(
        records: [solved],
        associations: {
          topic_answers: [{ post: :user }, :accepter],
        },
      ).call

      solved
        .topic_answers
        .sort_by { |ta| ta.post&.created_at }
        .filter_map do |ta|
          next unless ta.post

          AcceptedAnswerSerializer.new(
            ta.post,
            scope: guardian,
            root: false,
            accepter: ta.accepter,
          ).as_json
        end
    end
  end
end
