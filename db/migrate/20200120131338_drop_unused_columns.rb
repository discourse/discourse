# frozen_string_literal: true

class DropUnusedColumns < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS ||= {
    post_replies: %i{
      reply_id
    },
    user_profiles: %i{
      card_background
      profile_background
    }
  }

  def up
    DROPPED_COLUMNS.each do |table, columns|
      Migration::ColumnDropper.execute_drop(table, columns)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
