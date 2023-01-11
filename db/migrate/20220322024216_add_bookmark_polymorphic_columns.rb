# frozen_string_literal: true

class AddBookmarkPolymorphicColumns < ActiveRecord::Migration[6.1]
  def change
    if !column_exists?(:bookmarks, :bookmarkable_id)
      add_column :bookmarks, :bookmarkable_id, :integer
    end

    if !column_exists?(:bookmarks, :bookmarkable_type)
      add_column :bookmarks, :bookmarkable_type, :string
    end

    if !index_exists?(:bookmarks, %i[user_id bookmarkable_type bookmarkable_id])
      add_index :bookmarks,
                %i[user_id bookmarkable_type bookmarkable_id],
                name: "idx_bookmarks_user_polymorphic_unique",
                unique: true
    end
  end
end
