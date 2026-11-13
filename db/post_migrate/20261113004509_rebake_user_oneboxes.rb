# frozen_string_literal: true
class RebakeUserOneboxes < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE posts SET baked_version = NULL
      WHERE cooked LIKE '%user-onebox%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
