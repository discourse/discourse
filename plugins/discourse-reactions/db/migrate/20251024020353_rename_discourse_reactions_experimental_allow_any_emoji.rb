# frozen_string_literal: true
class RenameDiscourseReactionsExperimentalAllowAnyEmoji < ActiveRecord::Migration[8.0]
  def up
    DB.exec <<~SQL
      UPDATE site_settings SET name =  'discourse_reactions_allow_any_emoji'
      WHERE name = 'discourse_reactions_experimental_allow_any_emoji'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
