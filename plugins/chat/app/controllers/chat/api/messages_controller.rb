# frozen_string_literal: true

class Chat::Api::MessagesController < Chat::ApiController
  def delete
    with_service(Chat::TrashMessage) { on_model_not_found(:message) { raise Discourse::NotFound } }
  end
end
