# frozen_string_literal: true

module DiscourseAi
  module TopicExtensions
    extend ActiveSupport::Concern

    prepended do
      has_many :ai_summaries, as: :target

      has_one :ai_gist_summary,
              -> { where(summary_type: AiSummary.summary_types[:gist]) },
              class_name: "AiSummary",
              as: :target

      has_many :inferred_concept_topics
      has_many :inferred_concepts, through: :inferred_concept_topics

      has_many :ai_conversation_stars,
               class_name: "DiscourseAi::AiBot::ConversationStar",
               foreign_key: :topic_id

      def self.ai_conversation_custom_field_join_sql
        <<~SQL.squish
          INNER JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id
            AND tcf.name = #{connection.quote(DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD)}
            AND tcf.value = 't'
        SQL
      end
    end
  end
end
