# frozen_string_literal: true

class Chat::Api < Chat::ChatBaseController
  before_action :ensure_logged_in
  before_action :ensure_can_chat

  include Chat::WithServiceHelper

  private

  def ensure_can_chat
    raise Discourse::NotFound unless SiteSetting.chat_enabled
    guardian.ensure_can_chat!
  end
end
