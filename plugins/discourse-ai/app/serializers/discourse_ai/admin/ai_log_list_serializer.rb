# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiLogListSerializer < ApplicationSerializer
      attributes :id,
                 :created_at,
                 :provider_id,
                 :provider_name,
                 :feature_name,
                 :workflow,
                 :language_model,
                 :llm_id,
                 :model_name,
                 :user_id,
                 :username,
                 :avatar_template,
                 :topic_id,
                 :post_id,
                 :request_tokens,
                 :response_tokens,
                 :response_status,
                 :duration_msecs,
                 :has_retries,
                 :outcome

      def workflow
        id = DiscourseAi::WorkflowUsage.workflow_id(object)
        name = @options[:workflows_by_id]&.[](id)
        { id: id, name: name } if name
      end

      def outcome
        AiLogSerializerHelpers.outcome(object)
      end

      def provider_name
        AiLogSerializerHelpers.provider_name(object.provider_id)
      end

      def model_name
        object.llm_model&.display_name || object.language_model
      end

      def username
        object.user&.username
      end

      def avatar_template
        object.user&.avatar_template
      end

      def has_retries
        ActiveModel::Type::Boolean.new.cast(object[:has_retries])
      end
    end
  end
end
