# frozen_string_literal: true

class Chat::Api < Chat::ChatBaseController
  before_action :ensure_logged_in
  before_action :ensure_can_chat

  private

  def ensure_can_chat
    raise Discourse::NotFound unless SiteSetting.chat_enabled
    guardian.ensure_can_chat!
  end

  def handle_service_result(result)
    return { json: success_json } if result.success?

    raise Discourse::InvalidAccess if result[:"guardian.failed"]

    if result[:"contract.failed"]
      return { json: failed_json.merge(errors: contract.errors.full_messages), status: 400 }
    end

    { json: failed_json }
  end
end
