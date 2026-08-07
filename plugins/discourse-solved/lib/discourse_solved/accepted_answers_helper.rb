# frozen_string_literal: true

module DiscourseSolved
  module AcceptedAnswersHelper
    def self.serialize(topic, guardian)
      return nil unless topic.topic_answers&.any?

      ActiveRecord::Associations::Preloader.new(
        records: [topic.solved],
        associations: {
          topic_answers: [{ post: :user }, :accepter],
        },
      ).call

      answers =
        topic
          .topic_answers
          .select do |topic_answer|
            topic_answer.post.present? && guardian.can_see_post?(topic_answer.post)
          end
          .sort_by { |ta| ta.post.created_at }
          .map do |ta|
            AcceptedAnswerSerializer.new(
              ta.post,
              scope: guardian,
              root: false,
              accepter: ta.accepter,
            ).as_json
          end

      answers.presence
    end
  end
end
