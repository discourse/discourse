# frozen_string_literal: true

class MigrateToolDetailsToShowThinking < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      UPDATE ai_personas
      SET show_thinking = tool_details
      WHERE show_thinking != tool_details
    SQL

    # needs to be nullable to avoid issues inserting new rows
    change_column_null :ai_personas, :tool_details, true
    change_column_default :ai_personas, :tool_details, nil
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
