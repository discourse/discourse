# frozen_string_literal: true
class DeletePostLocalizationsWithLinks < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM post_localizations
      WHERE raw ~ 'https?://'
         OR cooked ~ 'https?://'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
