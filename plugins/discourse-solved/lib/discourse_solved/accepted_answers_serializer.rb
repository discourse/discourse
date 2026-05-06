# frozen_string_literal: true

module DiscourseSolved
  module AcceptedAnswersSerializer
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
        .sort_by(&:created_at)
        .filter_map do |ta|
          next unless ta.post

          serialized =
            PostExcerptAccordionItemSerializer.new(ta.post, scope: guardian, root: false).as_json

          if ta.accepter
            serialized[:accepter_username] = ta.accepter.username
            serialized[:accepter_name] = ta.accepter.name if SiteSetting.enable_names?
          end

          serialized
        end
    end
  end
end
