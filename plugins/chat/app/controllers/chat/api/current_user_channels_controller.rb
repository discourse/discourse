# frozen_string_literal: true

class Chat::Api::CurrentUserChannelsController < Chat::ApiController
  def index
    structured = Chat::ChannelFetcher.structured(guardian)
    render_serialized(structured, Chat::ChannelIndexSerializer, root: false)
  end
end
