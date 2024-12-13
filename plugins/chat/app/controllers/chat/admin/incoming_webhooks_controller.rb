# frozen_string_literal: true

module Chat
  module Admin
    class IncomingWebhooksController < ::Admin::AdminController
      requires_plugin Chat::PLUGIN_NAME

      def index
        render_serialized(
          {
            chat_channels: Chat::Channel.public_channels,
            incoming_chat_webhooks: Chat::IncomingWebhook.includes(:chat_channel).all,
          },
          Chat::AdminChatIndexSerializer,
          root: false,
        )
      end

      def edit
        webhook =
          Chat::IncomingWebhook.includes(:chat_channel).find(params[:incoming_chat_webhook_id])
        render_serialized(
          { chat_channels: Chat::Channel.public_channels, webhook: webhook },
          Chat::AdminChatWebhookShowSerializer,
          root: false,
        )
      end

      def new
        serialized_channels =
          Chat::Channel.public_channels.map do |channel|
            Chat::ChannelSerializer.new(channel, scope: Guardian.new(current_user))
          end

        render json: serialized_channels, root: "chat_channels"
      end

      def create
        params.require(%i[name chat_channel_id])

        chat_channel = Chat::Channel.find_by(id: params[:chat_channel_id])
        raise Discourse::NotFound if chat_channel.nil? || chat_channel.direct_message_channel?

        webhook = Chat::IncomingWebhook.new(name: params[:name], chat_channel: chat_channel)
        if webhook.save
          render_serialized(webhook, Chat::IncomingWebhookSerializer, root: false)
        else
          render_json_error(webhook)
        end
      end

      def update
        params.require(%i[incoming_chat_webhook_id name chat_channel_id])

        webhook = Chat::IncomingWebhook.find_by(id: params[:incoming_chat_webhook_id])
        raise Discourse::NotFound unless webhook

        chat_channel = Chat::Channel.find_by(id: params[:chat_channel_id])
        raise Discourse::NotFound if chat_channel.nil? || chat_channel.direct_message_channel?

        if webhook.update(
             name: params[:name],
             description: params[:description],
             emoji: params[:emoji],
             username: params[:username],
             chat_channel: chat_channel,
           )
          render json: success_json
        else
          render_json_error(webhook)
        end
      end

      def destroy
        params.require(:incoming_chat_webhook_id)

        webhook = Chat::IncomingWebhook.find_by(id: params[:incoming_chat_webhook_id])
        webhook.destroy if webhook
        render json: success_json
      end
    end
  end
end
