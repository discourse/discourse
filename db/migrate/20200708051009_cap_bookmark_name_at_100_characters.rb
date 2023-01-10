# frozen_string_literal: true

class CapBookmarkNameAt100Characters < ActiveRecord::Migration[6.0]
  def up
    DB.exec(
      "UPDATE bookmarks SET name = LEFT(name, 100) WHERE name IS NOT NULL AND name <> LEFT(name, 100)",
    )
    change_column :bookmarks, :name, :string, limit: 100
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
