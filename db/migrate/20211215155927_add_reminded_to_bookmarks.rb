# frozen_string_literal: true

class AddRemindedToBookmarks < ActiveRecord::Migration[6.1]
  def change
    add_column :bookmarks, :reminded, :boolean, default: false, null: false
  end
end
