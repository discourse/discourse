# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationsController < ::ApplicationController
      include AiCreditLimitHandler

      requires_plugin PLUGIN_NAME
      requires_login

      def index
        ListConversations.call(service_params) do
          on_success do |conversations:, meta:, starred_conversations:|
            serialized_conversations = conversations.records
            starred_at_by_topic_id =
              if SiteSetting.enable_ai_bot_starred_conversations
                ConversationStar.starred_at_by_topic_id(
                  current_user,
                  serialized_conversations + Array(starred_conversations),
                )
              else
                {}
              end
            serialize_topic = ->(topic) do
              ConversationListTopicSerializer.new(
                topic,
                scope: guardian,
                root: false,
                starred_at_by_topic_id: starred_at_by_topic_id,
              ).as_json
            end

            payload = { conversations: serialized_conversations.map(&serialize_topic), meta: meta }

            if SiteSetting.enable_ai_bot_starred_conversations
              payload[:starred_conversations] = Array(starred_conversations).map(&serialize_topic)
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

        UpdateConversationStar.call(star_service_params) do
          on_success { |params:| render json: success_json.merge(starred: params.starred) }
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

      def star_service_params
        service_params.deep_merge(params: { topic_id: params[:topic_id] })
      end
    end
  end
end
