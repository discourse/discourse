# frozen_string_literal: true

module Chat
  class BaseController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_can_chat

    private

    def ensure_can_chat
      guardian.ensure_can_chat!
    end

    def set_channel_and_chatable_with_access_check(chat_channel_id: nil)
      params.require(:chat_channel_id) if chat_channel_id.blank?
      id_or_name = chat_channel_id || params[:chat_channel_id]
      @chat_channel = Chat::ChannelFetcher.find_with_access_check(id_or_name, guardian)
      @chatable = @chat_channel.chatable
    end
  end
end
