# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiLogDetailSerializer < ApplicationSerializer
      attributes :id,
                 :created_at,
                 :provider_id,
                 :provider_name,
                 :feature_name,
                 :feature_context,
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
                 :cache_read_tokens,
                 :cache_write_tokens,
                 :response_status,
                 :duration_msecs,
                 :time_to_first_token_msecs,
                 :spending,
                 :request_attempts,
                 :raw_request_payload,
                 :raw_response_payload,
                 :raw_request_payload_bytes,
                 :raw_response_payload_bytes,
                 :raw_request_payload_truncated,
                 :raw_response_payload_truncated,
                 :payload_available

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

      def spending
        return object.estimated_cost.to_d.round(6).to_f if !object.estimated_cost.nil?

        object.llm_model&.spending_for(object)
      end

      def raw_request_payload_bytes
        object[:raw_request_payload_bytes]&.to_i
      end

      def raw_response_payload_bytes
        object[:raw_response_payload_bytes]&.to_i
      end

      def raw_request_payload_truncated
        raw_request_payload_bytes.to_i > object.raw_request_payload&.bytesize.to_i
      end

      def raw_response_payload_truncated
        raw_response_payload_bytes.to_i > object.raw_response_payload&.bytesize.to_i
      end

      def payload_available
        !raw_request_payload_bytes.nil? || !raw_response_payload_bytes.nil?
      end
    end
  end
end
