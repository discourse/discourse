# frozen_string_literal: true

class Chat::Api::ChatTrackingController < Chat::Api
  def read
    channel_id = params[:channel_id]
    message_id = params[:message_id]
  end
end
