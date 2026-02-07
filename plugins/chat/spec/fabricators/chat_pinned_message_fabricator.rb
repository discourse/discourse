# frozen_string_literal: true

Fabricator(:chat_pinned_message, class_name: "Chat::PinnedMessage") do
  chat_message { Fabricate(:chat_message) }
  chat_channel { |attrs| attrs[:chat_message].chat_channel }
  user { Fabricate(:user) }
end
