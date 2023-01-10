# frozen_string_literal: true

class Chat::Api::ChatCurrentUserChannelsController < Chat::Api
  def index
    structured = Chat::ChatChannelFetcher.structured(guardian)
    render_serialized(structured, ChatChannelIndexSerializer, root: false)
  end
end
