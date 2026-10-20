# frozen_string_literal: true

class NullifyDanglingAgentUserIds < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL if Migration::Helpers.existing_site?
        INSERT INTO plugin_store_rows (plugin_name, key, type_name, value)
        SELECT 'discourse-ai', 'bot_user_id_floor', 'Integer',
          LEAST(
            (SELECT min(id) FROM users),
            (SELECT min(user_id) FROM ai_agents),
            (SELECT min(user_id) FROM llm_models),
            -1200
          )::text
        ON CONFLICT (plugin_name, key) DO NOTHING
      SQL

    execute <<~SQL
      UPDATE ai_agents
      SET user_id = NULL
      WHERE user_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM users WHERE users.id = ai_agents.user_id)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
