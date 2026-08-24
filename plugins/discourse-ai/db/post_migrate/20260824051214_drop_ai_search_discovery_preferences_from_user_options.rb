# frozen_string_literal: true

class DropAiSearchDiscoveryPreferencesFromUserOptions < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = {
    user_options: %i[
      ai_search_discoveries_mode
      ai_search_discoveries_show_summary
      ai_search_discoveries_summary_detail
      ai_search_discoveries_related_count
    ],
  }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
