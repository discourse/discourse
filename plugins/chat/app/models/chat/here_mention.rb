# frozen_string_literal: true

module Chat
  class HereMention < Mention
    def identifier
      "here"
    end

    def should_notify?(user)
      !user.user_option.ignore_channel_wide_mention
    end
  end
end
