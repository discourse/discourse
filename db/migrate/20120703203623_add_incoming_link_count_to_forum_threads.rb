# frozen_string_literal: true

class AddIncomingLinkCountToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :incoming_link_count, :integer, default: 0, null: false
  end
end
