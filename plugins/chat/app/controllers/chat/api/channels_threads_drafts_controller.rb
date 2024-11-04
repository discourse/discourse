# frozen_string_literal: true

class Chat::Api::ChannelsThreadsDraftsController < Chat::ApiController
  def create
    Chat::UpsertDraft.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_step(:check_thread_exists) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
