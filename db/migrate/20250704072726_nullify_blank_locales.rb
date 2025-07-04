# frozen_string_literal: true
class NullifyBlankLocales < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE topics SET locale = NULL WHERE locale = '';
      UPDATE posts SET locale = NULL WHERE locale = '';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
