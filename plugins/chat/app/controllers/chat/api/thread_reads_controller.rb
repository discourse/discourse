# frozen_string_literal: true

class Chat::Api::ThreadReadsController < Chat::ApiController
  def update
    params.require(%i[channel_id thread_id])

    with_service(Chat::UpdateUserThreadLastRead) do
      on_model_not_found(:thread) { raise Discourse::NotFound }
    end
  end
end
