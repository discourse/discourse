# frozen_string_literal: true

# TODO: merge DMChannel and DirectMessageChannel models together
class DMChannel < ChatChannel
  alias_attribute :direct_message_channel, :chatable

  def direct_message_channel?
    true
  end

  def allowed_user_ids
    direct_message_channel.user_ids
  end

  def read_restricted?
    true
  end

  def title(user)
    direct_message_channel.chat_channel_title_for_user(self, user)
  end
end
