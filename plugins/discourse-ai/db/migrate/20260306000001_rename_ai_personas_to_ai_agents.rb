# frozen_string_literal: true

class RenameAiPersonasToAiAgents < ActiveRecord::Migration[7.2]
  def up
    Migration::SafeMigrate.disable!
    rename_table :ai_personas, :ai_agents

    # Backwards-compat view will be dropped immediately after deploy
    # by FinalizeAiAgentsSchema post-deploy migration
    execute "CREATE VIEW ai_personas AS SELECT * FROM ai_agents"
  ensure
    Migration::SafeMigrate.enable!
  end

  def down
    execute "DROP VIEW IF EXISTS ai_personas"
  end
end
