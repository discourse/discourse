# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationsController < ::ApplicationController
      include AiCreditLimitHandler

      requires_plugin PLUGIN_NAME
      requires_login

      def index
        ListConversations.call(service_params) do
          on_success do |list_result:|
            render json:
                     ConversationListSerializer.new(
                       list_result,
                       scope: guardian,
                       root: false,
                       starred_at_by_topic_id: list_result.starred_at_by_topic_id,
                     ).as_json
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
        UpdateConversationStar.call(star_service_params) do
          on_success { |params:| render json: success_json.merge(starred: params.starred) }
          on_failed_policy(:not_already_starred) { render json: success_json.merge(starred: true) }
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
