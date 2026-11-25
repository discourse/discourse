# frozen_string_literal: true

class RenameAdminAssistantToShortName < ActiveRecord::Migration[8.0]
  def up
    # Skip the agent rename if another agent already uses the new name
    # (ai_agents.name is unique); the seed fixture resolves that collision
    # with a suffixed name on the next seed run.
    execute <<~SQL
      UPDATE ai_agents
      SET name = 'Admin Assistant'
      WHERE id = -39
        AND name = 'Discourse Admin Assistant'
        AND NOT EXISTS (SELECT 1 FROM ai_agents WHERE name = 'Admin Assistant')
    SQL

    # Only rename the bot user when its agent carries the new name, so the
    # chat DM title stays consistent with the agent.
    execute <<~SQL
      UPDATE users
      SET name = 'Admin Assistant'
      WHERE id IN (SELECT user_id FROM ai_agents WHERE id = -39 AND name = 'Admin Assistant')
        AND name = 'Discourse Admin Assistant'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
