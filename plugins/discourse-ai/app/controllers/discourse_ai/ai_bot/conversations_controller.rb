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

      def create
        result = NewPostManager.new(current_user, create_params).perform
        json = serialize_data(result, NewPostResultSerializer, root: false).symbolize_keys
        status = json[:success] ? :ok : :unprocessable_entity
        json = json[:post] if json[:success] && json[:errors].blank? &&
          json[:action].to_s != "enqueued"

        render json: json, status: status
      rescue DiscourseAi::AiBot::ConversationRoute::Error => error
        render_json_error error.message, status: :unprocessable_entity
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

      def create_params
        route = conversation_route

        create_params = {
          raw: params.require(:raw),
          title: I18n.t("discourse_ai.ai_bot.default_pm_prefix"),
          archetype: Archetype.private_message,
          target_usernames: route.speaker.username,
          private_message_context: DiscourseAi::AiBot::PERSONAL_MESSAGE_CONTEXT,
          guardian: guardian,
          first_post_checks: true,
          advance_draft: true,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          referrer: request.env["HTTP_REFERER"],
          writing_device: BrowserDetection.device(request.user_agent),
          topic_opts: {
            custom_fields: {
              DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD => route.agent_id,
              DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD => route.llm_model_id,
            },
          },
        }

        create_params
      end

      def conversation_route
        username = params.require(:target_username).to_s.downcase
        recipient_user = User.find_by(username_lower: username)
        raise Discourse::InvalidParameters.new(:target_username) if recipient_user.blank?

        DiscourseAi::AiBot::ConversationRoute.resolve(
          authorization_user: current_user,
          modality: :personal_message,
          agent_id: params[:ai_agent_id],
          llm_model_id: params[:ai_llm_model_id],
          recipient_user:,
        )
      end

      def star_service_params
        service_params.deep_merge(params: { topic_id: params[:topic_id] })
      end
    end
  end
end
