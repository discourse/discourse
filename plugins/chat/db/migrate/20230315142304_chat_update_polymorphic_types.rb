# frozen_string_literal: true

class ChatUpdatePolymorphicTypes < ActiveRecord::Migration[7.0]
  def change
    execute "UPDATE bookmarks SET bookmarkable_type = 'Chat::Message' where bookmarkable_type = 'ChatMessage'"
    execute "UPDATE upload_references SET target_type = 'Chat::Message' where target_type = 'ChatMessage'"
    execute "UPDATE reviewables SET target_type = 'Chat::Message' where target_type = 'ChatMessage'"
    execute "UPDATE reviewables SET type = 'Chat::ReviewableChatMessage' where type = 'ReviewableChatMessage'"
    execute "UPDATE chat_channels SET chatable_type = 'Chat::DirectMessage' where chatable_type = 'DirectMessage'"
  end
end
