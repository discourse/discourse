# frozen_string_literal: true

module Chat
  class ApiController < ::Chat::BaseController
    include Chat::WithServiceHelper

    private

    def default_actions_for_service
      proc do
        on_success { render(json: success_json) }
        on_failure { render(json: failed_json, status: 422) }
        on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
        end
      end
    end
  end
end
