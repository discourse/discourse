# frozen_string_literal: true

class DropInvalidDrafts < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
    DELETE FROM drafts
    WHERE LENGTH(data) > 400000
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
