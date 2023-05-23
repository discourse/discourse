# frozen_string_literal: true

class Chat::Api::ChannelMessagesController < Chat::ApiController
  def destroy
    with_service(Chat::TrashMessage) { on_model_not_found(:message) { raise Discourse::NotFound } }
  end

  def restore
    with_service(Chat::RestoreMessage) do
      on_model_not_found(:message) { raise Discourse::NotFound }
    end
  end
end
