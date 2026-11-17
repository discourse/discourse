# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class SuggestDsaClassification
      include Service::Base

      params do
        attribute :reviewable_id, :integer

        validates :reviewable_id, presence: true
      end

      policy :classification_enabled
      model :decision_model
      model :reviewable
      model :suggestion, :suggest_classification

      private

      def classification_enabled
        DsaStatementOfRecord.classification_enabled?
      end

      def fetch_decision_model
        DecisionModel.find_by(id: SiteSetting.ai_dsa_classification_decision_model.presence)
      end

      def fetch_reviewable(params:, guardian:)
        Reviewable.viewable_by(guardian.user, preload: false).find_by(id: params.reviewable_id)
      end

      def suggest_classification(decision_model:, reviewable:, guardian:)
        DsaClassification::Classifier.new(decision_model).suggest(reviewable, user: guardian.user)
      end
    end
  end
end
