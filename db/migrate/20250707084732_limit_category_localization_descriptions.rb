# frozen_string_literal: true

class LimitCategoryLocalizationDescriptions < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE category_localizations
      SET description = LEFT(description, 1000)
      WHERE description IS NOT NULL AND LENGTH(description) > 1000;
    SQL

    change_column :category_localizations, :description, :string, limit: 1000
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
