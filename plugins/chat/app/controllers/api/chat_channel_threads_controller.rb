# frozen_string_literal: true

class Chat::Api::ChatChannelThreadsController < Chat::Api
  def show
    params.require(:channel_id)
    params.require(:thread_id)

    raise Discourse::NotFound if !SiteSetting.enable_experimental_chat_threaded_discussions

    thread =
      ChatThread
        .includes(:channel)
        .includes(original_message_user: :user_status)
        .includes(original_message: :chat_webhook_event)
        .find_by!(id: params[:thread_id], channel_id: params[:channel_id])

    guardian.ensure_can_preview_chat_channel!(thread.channel)

    render_serialized(thread, ChatThreadSerializer, root: "thread")
  end
end
