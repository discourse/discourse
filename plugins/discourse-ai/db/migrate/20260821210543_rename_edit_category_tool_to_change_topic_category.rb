# frozen_string_literal: true

class RenameEditCategoryToolToChangeTopicCategory < ActiveRecord::Migration[8.0]
  # The EditCategory tool used to move a topic to a different category; that
  # behavior now lives in ChangeTopicCategory while EditCategory edits the category
  # itself. Renaming the stored entry keeps existing agents doing what they
  # were configured to do.
  def up
    DB
      .query("SELECT id, tools FROM ai_agents WHERE tools::text LIKE '%EditCategory%'")
      .each do |row|
        tools = row.tools.is_a?(String) ? JSON.parse(row.tools) : row.tools
        next if !tools.is_a?(Array)

        names = tools.map { |tool| tool.is_a?(Array) ? tool.first : tool }
        next if names.include?("ChangeTopicCategory")

        renamed =
          tools.map do |tool|
            if tool.is_a?(Array) && tool.first == "EditCategory"
              ["ChangeTopicCategory", *tool.drop(1)]
            elsif tool == "EditCategory"
              "ChangeTopicCategory"
            else
              tool
            end
          end
        next if renamed == tools

        DB.exec(
          "UPDATE ai_agents SET tools = :tools WHERE id = :id",
          tools: renamed.to_json,
          id: row.id,
        )
      end

    # Pending approval actions replay by tool name; their stored parameters
    # (topic_id/category_id/reason) are the change_topic_category signature.
    execute "UPDATE ai_tool_actions SET tool_name = 'change_topic_category' WHERE tool_name = 'edit_category'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
