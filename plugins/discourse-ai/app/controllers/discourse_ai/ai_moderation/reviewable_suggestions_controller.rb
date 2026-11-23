# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class ReviewableSuggestionsController < ::ApplicationController
      LIMIT = 100

      requires_plugin PLUGIN_NAME
      requires_login

      before_action :check_xhr
      before_action :ensure_can_see_suggestions

      def index
        relation =
          Reviewable.list_for(current_user, status: :pending).joins(:ai_reviewable_suggestion)
        reviewables = relation.limit(LIMIT).to_a
        claimed_user_ids = claimed_user_ids_for(reviewables)

        suggestions =
          reviewables.filter_map do |reviewable|
            serializer =
              AiReviewableSuggestionSerializer.new(
                reviewable,
                scope: guardian,
                root: false,
                claimed_user_ids:,
              )
            serializer.as_json if serializer.suggested_action
          end

        render json: { suggestions:, total: relation.count }
      end

      private

      def ensure_can_see_suggestions
        if !guardian.is_staff? || !SiteSetting.ai_reviewable_action_suggestions_enabled
          raise Discourse::InvalidAccess
        end
      end

      def claimed_user_ids_for(reviewables)
        return {} if SiteSetting.reviewable_claiming == "disabled"

        ReviewableClaimedTopic
          .where(topic_id: reviewables.filter_map(&:topic_id).uniq)
          .pluck(:topic_id, :user_id)
          .to_h
      end
    end
  end
end
