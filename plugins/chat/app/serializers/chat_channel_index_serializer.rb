# frozen_string_literal: true

class ChatChannelIndexSerializer < StructuredChannelSerializer
  attributes :global_presence_channel_state

  def global_presence_channel_state
    PresenceChannelStateSerializer.new(PresenceChannel.new("/chat/online").state, root: nil)
  end
end
