# frozen_string_literal: true

class AddPinnedColumnToBookmarks < ActiveRecord::Migration[6.0]
  def change
    add_column :bookmarks, :pinned, :boolean, default: false
  end
end
