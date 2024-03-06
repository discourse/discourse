# frozen_string_literal: true

class AddForceToThreads < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_threads, :force, :boolean, null: false, default: false
  end
end
