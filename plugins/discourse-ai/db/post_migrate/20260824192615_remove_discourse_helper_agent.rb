# frozen_string_literal: true

class RemoveDiscourseHelperAgent < ActiveRecord::Migration[8.0]
  DISCOURSE_HELPER_AGENT_ID = -8

  def up
    execute <<~SQL
      INSERT INTO topic_custom_fields (topic_id, name, value, created_at, updated_at)
      SELECT agent_fields.topic_id, 'ai_agent', agents.name, NOW(), NOW()
      FROM topic_custom_fields agent_fields
      INNER JOIN ai_agents agents ON agents.id = #{DISCOURSE_HELPER_AGENT_ID}
      WHERE agent_fields.name = 'ai_agent_id'
        AND agent_fields.value = '#{DISCOURSE_HELPER_AGENT_ID}'
        AND NOT EXISTS (
          SELECT 1
          FROM topic_custom_fields existing_fields
          WHERE existing_fields.topic_id = agent_fields.topic_id
            AND existing_fields.name = 'ai_agent'
        )
    SQL

    execute <<~SQL
      UPDATE ai_agents
      SET subagent_ids = array_remove(subagent_ids, #{DISCOURSE_HELPER_AGENT_ID})
      WHERE #{DISCOURSE_HELPER_AGENT_ID} = ANY(subagent_ids)
    SQL

    execute <<~SQL
      DELETE FROM rag_document_fragments
      WHERE target_type = 'AiAgent' AND target_id = #{DISCOURSE_HELPER_AGENT_ID}
    SQL

    execute <<~SQL
      DELETE FROM rag_document_sources
      WHERE target_type = 'AiAgent' AND target_id = #{DISCOURSE_HELPER_AGENT_ID}
    SQL

    execute <<~SQL
      DELETE FROM upload_references
      WHERE target_type = 'AiAgent' AND target_id = #{DISCOURSE_HELPER_AGENT_ID}
    SQL

    execute <<~SQL
      DELETE FROM ai_agent_mcp_servers
      WHERE ai_agent_id = #{DISCOURSE_HELPER_AGENT_ID}
    SQL

    execute "DELETE FROM ai_agents WHERE id = #{DISCOURSE_HELPER_AGENT_ID}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
