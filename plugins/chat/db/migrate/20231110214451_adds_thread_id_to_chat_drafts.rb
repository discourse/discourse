# frozen_string_literal: true

class AddsThreadIdToChatDrafts < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_drafts, :thread_id, :bigint
  end
end
