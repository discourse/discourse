# frozen_string_literal: true

class RenameShaColumn < ActiveRecord::Migration[4.2]
  def up
    remove_index :uploads, :sha
    rename_column :uploads, :sha, :sha1
    change_column :uploads, :sha1, :string, limit: 40
    add_index :uploads, :sha1, unique: true
  end

  def down
    remove_index :uploads, :sha1
    change_column :uploads, :sha1, :string, limit: 255
    rename_column :uploads, :sha1, :sha
    add_index :uploads, :sha, unique: true
  end
end
