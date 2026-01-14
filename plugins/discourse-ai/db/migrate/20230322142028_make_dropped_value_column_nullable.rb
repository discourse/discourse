# frozen_string_literal: true
class MakeDroppedValueColumnNullable < ActiveRecord::Migration[7.0]
  def up
    if column_exists?(:completion_prompts, :value)
      Migration::SafeMigrate.disable!
      change_column_null :completion_prompts, :value, true
      Migration::SafeMigrate.enable!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
