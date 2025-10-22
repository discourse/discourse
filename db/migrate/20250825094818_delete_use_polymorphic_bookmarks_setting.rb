# frozen_string_literal: true
class DeleteUsePolymorphicBookmarksSetting < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'use_polymorphic_bookmarks'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
