# frozen_string_literal: true

class Chat::Api::ChannelsThreadsDraftsController < Chat::ApiController
  def create
    with_service(Chat::UpsertDraft) do
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_step(:check_thread_exists) { raise Discourse::NotFound }
    end
  end
end
