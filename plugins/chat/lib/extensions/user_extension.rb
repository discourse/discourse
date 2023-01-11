# frozen_string_literal: true

module Chat::UserExtension
  extend ActiveSupport::Concern

  prepended do
    has_many :user_chat_channel_memberships, dependent: :destroy
    has_many :chat_message_reactions, dependent: :destroy
    has_many :chat_mentions
  end
end
