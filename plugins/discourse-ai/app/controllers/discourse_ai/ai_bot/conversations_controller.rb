# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationsController < ::ApplicationController
      include AiCreditLimitHandler

      requires_plugin PLUGIN_NAME
      requires_login

      def index
        ListConversations.call(service_params) do
          on_success do |conversations:, starred_conversations:, starred_enabled:, starred_at_by_topic_id:, meta:|
            payload = {
              conversations: serialized_conversations(conversations, starred_at_by_topic_id),
              meta: meta,
            }

            if starred_enabled
              payload[:starred_conversations] = serialized_conversations(
                starred_conversations,
                starred_at_by_topic_id,
              )
            end

            render json: payload
          end
          on_failed_contract do |contract|
            render(
              json: failed_json.merge(errors: contract.errors.full_messages),
              status: :bad_request,
            )
          end
          on_failure { render(json: failed_json, status: :unprocessable_entity) }
        end
      end

      def update_starred
        unless SiteSetting.enable_ai_bot_starred_conversations
          return render(json: failed_json, status: :not_found)
        end

        unless valid_starred_param?
          return(
            render(json: failed_json.merge(errors: ["starred is invalid"]), status: :bad_request)
          )
        end

        UpdateConversationStar.call(star_service_params) do
          on_success { render json: success_json.merge(starred: normalized_starred) }
          on_model_not_found(:topic) { raise Discourse::NotFound }
          on_failed_policy(:feature_enabled) { raise Discourse::NotFound }
          on_failed_policy(:can_access_conversation) { raise Discourse::NotFound }
          on_failed_contract do |contract|
            render(
              json: failed_json.merge(errors: contract.errors.full_messages),
              status: :bad_request,
            )
          end
          on_failure { render(json: failed_json, status: :unprocessable_entity) }
        end
      end

      private

      def valid_starred_param?
        [true, false, "true", "false"].include?(params[:starred])
      end

      def normalized_starred
        ActiveModel::Type::Boolean.new.cast(params[:starred])
      end

      def star_service_params
        service_params.deep_merge(
          params: {
            topic_id: params[:topic_id],
            starred: normalized_starred,
          },
        )
      end

      def serialized_conversations(topics, starred_at_by_topic_id)
        serialized = serialize_data(topics, ListableTopicSerializer)

        serialized.each do |topic|
          topic_id = topic[:id] || topic["id"]
          starred_at = starred_at_by_topic_id[topic_id]
          topic[:ai_conversation_starred] = starred_at.present?
          topic[:ai_conversation_starred_at] = starred_at&.iso8601
        end

        serialized
      end
    end
  end
end
