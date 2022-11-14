# frozen_string_literal: true

class Chat::AdminIncomingChatWebhooksController < Admin::AdminController
  requires_plugin Chat::PLUGIN_NAME

  def index
    render_serialized(
      {
        chat_channels: ChatChannel.public_channels,
        incoming_chat_webhooks: IncomingChatWebhook.includes(:chat_channel).all,
      },
      AdminChatIndexSerializer,
      root: false,
    )
  end

  def create
    params.require(%i[name chat_channel_id])

    chat_channel = ChatChannel.find_by(id: params[:chat_channel_id])
    raise Discourse::NotFound if chat_channel.nil? || chat_channel.direct_message_channel?

    webhook = IncomingChatWebhook.new(name: params[:name], chat_channel: chat_channel)
    if webhook.save
      render_serialized(webhook, IncomingChatWebhookSerializer, root: false)
    else
      render_json_error(webhook)
    end
  end

  def update
    params.require(%i[incoming_chat_webhook_id name chat_channel_id])

    webhook = IncomingChatWebhook.find_by(id: params[:incoming_chat_webhook_id])
    raise Discourse::NotFound unless webhook

    chat_channel = ChatChannel.find_by(id: params[:chat_channel_id])
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

    webhook = IncomingChatWebhook.find_by(id: params[:incoming_chat_webhook_id])
    webhook.destroy if webhook
    render json: success_json
  end
end
