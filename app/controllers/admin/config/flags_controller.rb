# frozen_string_literal: true

class Admin::Config::FlagsController < Admin::AdminController
  def toggle
    with_service(ToggleFlag) do
      on_success do
        Discourse.request_refresh!
        render(json: success_json)
      end
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def index
  end
end
