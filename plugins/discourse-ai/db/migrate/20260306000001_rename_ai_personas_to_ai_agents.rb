# frozen_string_literal: true

class RenameAiPersonasToAiAgents < ActiveRecord::Migration[7.2]
  def up
    # Create ai_agents as a view pointing to the real ai_personas table.
    # New code references ai_agents; old table stays intact until
    # FinalizeAiAgentsSchema post_migration does the actual rename.
    if table_exists?(:ai_personas) && !ActiveRecord::Base.connection.view_exists?(:ai_agents)
      execute "CREATE VIEW ai_agents AS SELECT * FROM ai_personas"
    end
  end

  def down
    execute "DROP VIEW IF EXISTS ai_agents"
  end
end
