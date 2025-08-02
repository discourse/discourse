# frozen_string_literal: true

module Chat
  class ChatController < ::Chat::BaseController
    # Other endpoints use set_channel_and_chatable_with_access_check, but
    # these endpoints require a standalone find because they need to be
    # able to get deleted channels and recover them.
    before_action :find_chat_message, only: %i[rebake]
    before_action :set_channel_and_chatable_with_access_check,
                  except: %i[respond set_user_chat_status dismiss_retention_reminder]

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
      guardian.ensure_can_rebake_chat_message!(@message)
      @message.rebake!(invalidate_oneboxes: true)
      render json: success_json
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

    private

    def preloaded_chat_message_query
      query =
        Chat::Message
          .includes(in_reply_to: [:user, chat_webhook_event: [:incoming_chat_webhook]])
          .includes(:revisions)
          .includes(user: :primary_group)
          .includes(chat_webhook_event: :incoming_chat_webhook)
          .includes(reactions: :user)
          .includes(:bookmarks)
          .includes(:uploads)
          .includes(chat_channel: :chatable)
          .includes(:thread)
          .includes(:chat_mentions)

      query = query.includes(user: :user_status) if SiteSetting.enable_user_status

      query
    end

    def find_chat_message
      @message = preloaded_chat_message_query.with_deleted
      @message = @message.where(chat_channel_id: params[:chat_channel_id]) if params[
        :chat_channel_id
      ]
      @message = @message.find_by(id: params[:message_id])
      raise Discourse::NotFound unless @message
    end
  end
end
