# frozen_string_literal: true

class AlterBookmarksIdsToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :bookmarks, :bookmarkable_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
