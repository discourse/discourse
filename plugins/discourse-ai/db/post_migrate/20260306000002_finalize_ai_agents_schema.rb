# frozen_string_literal: true

class FinalizeAiAgentsSchema < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  PERSONA_TO_AGENT_SETTINGS = {
    "ai_helper_proofreader_persona" => "ai_helper_proofreader_agent",
    "ai_helper_title_suggestions_persona" => "ai_helper_title_suggestions_agent",
    "ai_helper_explain_persona" => "ai_helper_explain_agent",
    "ai_helper_post_illustrator_persona" => "ai_helper_post_illustrator_agent",
    "ai_helper_smart_dates_persona" => "ai_helper_smart_dates_agent",
    "ai_helper_translator_persona" => "ai_helper_translator_agent",
    "ai_helper_markdown_tables_persona" => "ai_helper_markdown_tables_agent",
    "ai_helper_custom_prompt_persona" => "ai_helper_custom_prompt_agent",
    "ai_helper_image_caption_persona" => "ai_helper_image_caption_agent",
    "ai_helper_chat_thread_title_persona" => "ai_helper_chat_thread_title_agent",
    "ai_embeddings_semantic_search_hyde_persona" => "ai_embeddings_semantic_search_hyde_agent",
    "ai_summarization_persona" => "ai_summarization_agent",
    "ai_summary_gists_persona" => "ai_summary_gists_agent",
    "ai_discover_persona" => "ai_discover_agent",
    "ai_discord_search_persona" => "ai_discord_search_agent",
    "ai_translation_locale_detector_persona" => "ai_translation_locale_detector_agent",
    "ai_translation_post_raw_translator_persona" => "ai_translation_post_raw_translator_agent",
    "ai_translation_topic_title_translator_persona" =>
      "ai_translation_topic_title_translator_agent",
    "ai_translation_short_text_translator_persona" => "ai_translation_short_text_translator_agent",
    "inferred_concepts_generate_persona" => "inferred_concepts_generate_agent",
    "inferred_concepts_match_persona" => "inferred_concepts_match_agent",
    "inferred_concepts_deduplicate_persona" => "inferred_concepts_deduplicate_agent",
  }

  def up
    # 0. Drop the forward-compat view and do the actual table rename
    execute "DROP VIEW IF EXISTS ai_agents"

    if table_exists?(:ai_personas) && !table_exists?(:ai_agents)
      rename_table :ai_personas, :ai_agents
    end

    raise "ai_agents table must exist at this point" unless table_exists?(:ai_agents)

    if table_exists?(:ai_moderation_settings) &&
         column_exists?(:ai_moderation_settings, :ai_persona_id)
      rename_column :ai_moderation_settings, :ai_persona_id, :ai_agent_id
    end

    # 1. Update polymorphic target_type references
    execute <<~SQL
      UPDATE rag_document_fragments
      SET target_type = 'AiAgent'
      WHERE target_type = 'AiPersona'
    SQL

    execute <<~SQL
      UPDATE upload_references
      SET target_type = 'AiAgent'
      WHERE target_type = 'AiPersona'
    SQL

    # 2. Rename site settings
    PERSONA_TO_AGENT_SETTINGS.each { |old_name, new_name| execute <<~SQL }
        UPDATE site_settings
        SET name = '#{new_name}'
        WHERE name = '#{old_name}'
          AND NOT EXISTS (SELECT 1 FROM site_settings WHERE name = '#{new_name}')
      SQL

    # 3. Rename custom fields
    execute <<~SQL
      UPDATE topic_custom_fields
      SET name = 'ai_agent_id'
      WHERE name = 'ai_persona_id'
    SQL

    execute <<~SQL
      UPDATE topic_custom_fields
      SET name = 'ai_agent'
      WHERE name = 'ai_persona'
    SQL

    execute <<~SQL
      UPDATE post_custom_fields
      SET name = 'ai_agent_id'
      WHERE name = 'ai_persona_id'
    SQL

    # 3b. Rename automation script and field names
    execute <<~SQL
      UPDATE discourse_automation_automations
      SET script = 'llm_agent_triage'
      WHERE script = 'llm_persona_triage'
    SQL

    execute <<~SQL
      UPDATE discourse_automation_fields
      SET name = 'agent'
      WHERE name = 'persona'
        AND automation_id IN (
          SELECT id FROM discourse_automation_automations
          WHERE script = 'llm_agent_triage'
        )
    SQL

    execute <<~SQL
      UPDATE discourse_automation_fields
      SET name = 'triage_agent'
      WHERE name = 'triage_persona'
        AND automation_id IN (
          SELECT id FROM discourse_automation_automations
          WHERE script = 'llm_triage'
        )
    SQL

    execute <<~SQL
      UPDATE discourse_automation_fields
      SET name = 'reply_agent'
      WHERE name = 'reply_persona'
        AND automation_id IN (
          SELECT id FROM discourse_automation_automations
          WHERE script = 'llm_triage'
        )
    SQL

    execute <<~SQL
      UPDATE discourse_automation_fields
      SET name = 'agent_id'
      WHERE name = 'persona_id'
        AND automation_id IN (
          SELECT id FROM discourse_automation_automations
          WHERE script = 'llm_report'
        )
    SQL

    execute <<~SQL
      UPDATE discourse_automation_fields
      SET name = 'tagger_agent'
      WHERE name = 'tagger_persona'
        AND automation_id IN (
          SELECT id FROM discourse_automation_automations
          WHERE script = 'llm_tagger'
        )
    SQL

    # 4. Ensure stale columns are gone (idempotent cleanup)
    remove_column :ai_agents, :default_llm if column_exists?(:ai_agents, :default_llm)
    if column_exists?(:ai_agents, :question_consolidator_llm)
      remove_column :ai_agents, :question_consolidator_llm
    end
    remove_column :ai_agents, :tool_details if column_exists?(:ai_agents, :tool_details)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
