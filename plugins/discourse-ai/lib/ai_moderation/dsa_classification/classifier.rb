# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    module DsaClassification
      class Classifier
        MAX_CONTEXT_CHARS = 6000

        def initialize(decision_model, questions: Questions.new)
          @decision_model = decision_model
          @questions = questions
        end

        def suggest(reviewable, user:)
          context = context_for(reviewable, user:)
          return Suggestion.new(community_rule: nil, category: nil) if context.blank?

          result =
            @decision_model.decide(
              context,
              questions: @questions.to_a,
              feature_name: FEATURE_NAME,
              user:,
            )
          @questions.suggestion_from(result)
        end

        private

        def context_for(reviewable, user:)
          data =
            Reviewable.with_deleted_content do
              reviewable.serializer.new(reviewable, scope: user.guardian, root: false).as_json
            end
          payload = data[:payload] || {}
          content =
            data[:raw].presence || payload["raw"].presence || data[:cooked].presence ||
              payload["message_cooked"].presence
          profile = payload.slice("name", "bio", "website").compact_blank
          return if content.blank? && profile.blank?

          context = {
            flag_reasons:
              reviewable
                .reviewable_scores
                .map do |score|
                  ReviewableScore.type_title(ReviewableScore.types.key(score.reviewable_score_type))
                end
                .compact_blank
                .uniq,
            title: payload["title"].presence || reviewable.topic&.title,
            author: payload["username"].presence || reviewable.target_created_by&.username,
            profile:,
            content:,
          }
          JSON.generate(context.compact_blank)[0, MAX_CONTEXT_CHARS]
        end
      end
    end
  end
end
