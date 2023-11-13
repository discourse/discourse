# frozen_string_literal: true

module Chat
  class ChatController < ::Chat::BaseController
    # Other endpoints use set_channel_and_chatable_with_access_check, but
    # these endpoints require a standalone find because they need to be
    # able to get deleted channels and recover them.
    before_action :find_chat_message, only: %i[rebake message_link]
    before_action :set_channel_and_chatable_with_access_check,
                  except: %i[
                    respond
                    message_link
                    set_user_chat_status
                    dismiss_retention_reminder
                    flag
                  ]

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

    def message_link
      raise Discourse::NotFound if @message.blank? || @message.deleted_at.present?
      raise Discourse::NotFound if @message.chat_channel.blank?
      set_channel_and_chatable_with_access_check(chat_channel_id: @message.chat_channel_id)
      render json:
               success_json.merge(
                 chat_channel_id: @chat_channel.id,
                 chat_channel_title: @chat_channel.title(current_user),
               )
    end

    def set_user_chat_status
      params.require(:chat_enabled)

      current_user.user_option.update(chat_enabled: params[:chat_enabled])
      render json: { chat_enabled: current_user.user_option.chat_enabled }
    end

    def dismiss_retention_reminder
      params.require(:chatable_type)
      guardian.ensure_can_chat!
      unless Chat::Channel.chatable_types.include?(params[:chatable_type])
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

    def flag
      RateLimiter.new(current_user, "flag_chat_message", 4, 1.minutes).performed!

      permitted_params =
        params.permit(
          %i[chat_message_id flag_type_id message is_warning take_action queue_for_review],
        )

      chat_message =
        Chat::Message.includes(:chat_channel, :revisions).find(permitted_params[:chat_message_id])

      flag_type_id = permitted_params[:flag_type_id].to_i

      if !ReviewableScore.types.values.include?(flag_type_id)
        raise Discourse::InvalidParameters.new(:flag_type_id)
      end

      set_channel_and_chatable_with_access_check(chat_channel_id: chat_message.chat_channel_id)

      result =
        Chat::ReviewQueue.new.flag_message(chat_message, guardian, flag_type_id, permitted_params)

      if result[:success]
        render json: success_json
      else
        render_json_error(result[:errors])
      end
    end

    def set_draft
      if params[:data].present?
        Chat::Draft.find_or_initialize_by(
          user: current_user,
          chat_channel_id: @chat_channel.id,
        ).update!(data: params[:data])
      else
        Chat::Draft.where(user: current_user, chat_channel_id: @chat_channel.id).destroy_all
      end

      render json: success_json
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
