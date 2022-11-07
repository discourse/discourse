# frozen_string_literal: true

class DirectMessageChannel < ChatChannel
  alias_attribute :direct_message, :chatable

  def direct_message_channel?
    true
  end

  def allowed_user_ids
    direct_message.user_ids
  end

  def read_restricted?
    true
  end

  def title(user)
    direct_message.chat_channel_title_for_user(self, user)
  end
end
