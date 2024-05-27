# frozen_string_literal: true

class AddThreadTitlePromptToUserChatThreadMemberships < ActiveRecord::Migration[7.0]
  def change
    add_column :user_chat_thread_memberships,
               :thread_title_prompt_seen,
               :boolean,
               default: false,
               null: false
  end
end
