# frozen_string_literal: true

class Chat::Api::ThreadReadsController < Chat::ApiController
  def update
    params.require(%i[channel_id thread_id])

    with_service(Chat::UpdateUserThreadLastRead) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:thread) { raise Discourse::NotFound }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
    end
  end
end
