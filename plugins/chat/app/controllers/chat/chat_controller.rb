# frozen_string_literal: true

module Chat
  class ChatController < ::Chat::BaseController
    before_action :set_channel_and_chatable_with_access_check,
                  except: %i[respond set_user_chat_status dismiss_retention_reminder rebake]

    def respond
      render
    end

    def react
      params.require(%i[message_id emoji react_action])
      guardian.ensure_can_react!

      Chat::MessageReactor.new(current_user, @chat_channel).react!(
        message_id: params[:message_id],
        react_action: params[:react_action].to_sym,
        emoji: params[:emoji],
      )

      render json: success_json
    end

    def rebake
      Chat::RebakeMessage.call(service_params) do
        on_success { render(json: success_json) }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:channel) { raise Discourse::NotFound }
        on_failed_policy(:can_access_channel) { raise Discourse::InvalidAccess }
        on_model_not_found(:message) { raise Discourse::NotFound }
        on_failed_policy(:can_rebake) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
      end
    end

    def set_user_chat_status
      params.require(:chat_enabled)

      current_user.user_option.update(chat_enabled: params[:chat_enabled])
      render json: { chat_enabled: current_user.user_option.chat_enabled }
    end

    def dismiss_retention_reminder
      params.require(:chatable_type)
      guardian.ensure_can_chat!
      if Chat::Channel.chatable_types.exclude?(params[:chatable_type])
        raise Discourse::InvalidParameters
      end

      field =
        (
          if Chat::Channel.public_channel_chatable_types.include?(params[:chatable_type])
            :dismissed_channel_retention_reminder
          else
            :dismissed_dm_retention_reminder
          end
        )
      current_user.user_option.update(field => true)
      render json: success_json
    end

    def quote_messages
      params.require(:message_ids)

      message_ids = params[:message_ids].map(&:to_i)
      markdown =
        Chat::TranscriptService.new(
          @chat_channel,
          current_user,
          messages_or_ids: message_ids,
        ).generate_markdown
      render json: success_json.merge(markdown: markdown)
    end
  end
end
