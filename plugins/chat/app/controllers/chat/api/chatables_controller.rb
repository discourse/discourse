# frozen_string_literal: true

class Chat::Api::ChatablesController < Chat::ApiController
  before_action :ensure_logged_in

  def index
    ::Chat::SearchChatable.call(service_params) do |result|
      on_success { render_serialized(result, ::Chat::ChatablesSerializer, root: false) }
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end
end
