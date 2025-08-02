# frozen_string_literal: true

class ToolDetailsAndCommandRemoval < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_personas, :tool_details, :boolean, default: true, null: false
    add_column :ai_personas, :tools, :json, null: false, default: []
    # we can not do this cause we are seeding the data and in certain
    # build scenarios we seed prior to running post migrations
    # this risks potentially dropping data but the window is small
    # Migration::ColumnDropper.mark_readonly(:ai_personas, :commands)

    execute <<~SQL
      UPDATE ai_personas
      SET tools = commands
    SQL
  end
end
