# frozen_string_literal: true

class Chat::Api::ChatThreadsController < Chat::Api
  def show
    render_serialized(
      ChatThread.includes(:original_message, :original_message_user).find(params[:thread_id]),
      ChatThreadSerializer,
      root: "thread",
    )
  end
end
