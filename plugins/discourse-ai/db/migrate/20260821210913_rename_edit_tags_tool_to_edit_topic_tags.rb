# frozen_string_literal: true

class RenameEditTagsToolToEditTopicTags < ActiveRecord::Migration[8.0]
  # The tool that tags a topic was renamed from EditTags to EditTopicTags to
  # distinguish it from the new EditTag tool that edits a tag itself. Rename
  # the stored entry so existing agents keep the tool.
  def up
    DB
      .query("SELECT id, tools FROM ai_agents WHERE tools::text LIKE '%EditTags%'")
      .each do |row|
        tools = row.tools.is_a?(String) ? JSON.parse(row.tools) : row.tools
        next if !tools.is_a?(Array)

        names = tools.map { |tool| tool.is_a?(Array) ? tool.first : tool }
        next if names.include?("EditTopicTags")

        renamed =
          tools.map do |tool|
            if tool.is_a?(Array) && tool.first == "EditTags"
              ["EditTopicTags", *tool.drop(1)]
            elsif tool == "EditTags"
              "EditTopicTags"
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
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
