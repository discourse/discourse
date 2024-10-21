# frozen_string_literal: true

module Chat
  class DirectMessageChannel < Channel
    alias_method :direct_message, :chatable

    delegate :group?, to: :direct_message, prefix: true, allow_nil: true

    before_validation(on: :create) { self.threading_enabled = true }

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

    def generate_auto_slug
      self.slug.blank?
    end

    def leave(user)
      return super unless direct_message_group?
      transaction do
        membership_for(user)&.destroy!
        direct_message.users.delete(user)
      end
    end
  end
end
