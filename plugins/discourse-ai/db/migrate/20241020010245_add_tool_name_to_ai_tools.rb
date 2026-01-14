# frozen_string_literal: true

class AddToolNameToAiTools < ActiveRecord::Migration[7.1]
  def up
    add_column :ai_tools,
               :tool_name,
               :string,
               null: false,
               limit: 100,
               default: "",
               if_not_exists: true

    # Migrate existing name to tool_name
    execute <<~SQL
      UPDATE ai_tools
      SET tool_name = regexp_replace(LOWER(name),'[^a-z0-9_]','', 'g');
    SQL
  end

  def down
    remove_column :ai_tools, :tool_name, if_exists: true
  end
end
