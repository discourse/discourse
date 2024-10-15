# frozen_string_literal: true

class DropBadgeGrantedTitleColumn < ActiveRecord::Migration[7.0]
  DROPPED_COLUMNS = { user_profiles: %i[badge_granted_title] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
