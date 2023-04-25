# frozen_string_literal: true

module Chat
  class ApiController < ::Chat::BaseController
    before_action :ensure_logged_in
    before_action :ensure_can_chat

    include Chat::WithServiceHelper

    private

    def ensure_can_chat
      raise Discourse::NotFound unless SiteSetting.chat_enabled
      guardian.ensure_can_chat!
    end

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

    def record_invalid(name = :model)
      render_json_error(result[name], type: :record_invalid, status: 422)
    end
  end
end
