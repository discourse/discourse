# frozen_string_literal: true

class Chat::Api::ChannelsDraftsController < Chat::ApiController
  def create
    with_service(Chat::UpsertDraft) { on_model_not_found(:channel) { raise Discourse::NotFound } }
  end
end
