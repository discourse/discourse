# frozen_string_literal: true

class AddDeleteOnOwnerReplyBookmarkOption < ActiveRecord::Migration[6.0]
  def change
    add_column :bookmarks, :delete_on_owner_reply, :boolean, default: false
  end
end
