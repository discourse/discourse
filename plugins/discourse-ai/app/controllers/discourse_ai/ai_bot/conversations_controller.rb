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
        bot_user = find_bot_user!
        topic_custom_fields = create_topic_custom_fields

        create_params = {
          raw: params.require(:raw),
          title: I18n.t("discourse_ai.ai_bot.default_pm_prefix"),
          archetype: Archetype.private_message,
          target_usernames: bot_user.username,
          private_message_context: DiscourseAi::AiBot::PERSONAL_MESSAGE_CONTEXT,
          guardian: guardian,
          first_post_checks: true,
          advance_draft: true,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          referrer: request.env["HTTP_REFERER"],
          writing_device: BrowserDetection.device(request.user_agent),
        }

        if topic_custom_fields.present?
          create_params[:topic_opts] = { custom_fields: topic_custom_fields }
        end

        create_params
      end

      def find_bot_user!
        username = params.require(:target_username).to_s.downcase
        bot_user = User.find_by(username_lower: username)
        raise Discourse::InvalidParameters.new(:target_username) if bot_user.blank?

        guardian.ensure_can_send_pm_to_ai_bot!(bot_user)

        bot_user
      end

      def create_topic_custom_fields
        return {} if params[:ai_agent_id].blank?

        agent =
          DiscourseAi::Agents::Agent.find_by(user: current_user, id: params[:ai_agent_id].to_i)
        if agent.blank? || !agent.allow_personal_messages
          raise Discourse::InvalidParameters.new(:ai_agent_id)
        end

        { "ai_agent_id" => agent.id }
      end

      def star_service_params
        service_params.deep_merge(params: { topic_id: params[:topic_id] })
      end
    end
  end
end
