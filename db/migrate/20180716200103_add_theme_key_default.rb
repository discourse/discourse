# frozen_string_literal: true

class AddThemeKeyDefault < ActiveRecord::Migration[5.2]
  def up
    if column_exists?(:themes, :key)
      execute("ALTER TABLE themes ALTER COLUMN key SET DEFAULT 'deprecated'")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
