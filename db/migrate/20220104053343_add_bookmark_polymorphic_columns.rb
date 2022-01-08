# frozen_string_literal: true

class AddBookmarkPolymorphicColumns < ActiveRecord::Migration[6.1]
  def change
    add_column :bookmarks, :bookmarkable_id, :integer
    add_column :bookmarks, :bookmarkable_type, :string

    add_index :bookmarks, [:user_id, :bookmarkable_type, :bookmarkable_id], name: "idx_bookmarks_user_polymorphic_unique", unique: true
  end
end
