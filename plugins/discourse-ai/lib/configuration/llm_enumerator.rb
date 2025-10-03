# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class LlmEnumerator < ::EnumSiteSetting
      def self.global_usage
        rval = Hash.new { |h, k| h[k] = [] }

        if SiteSetting.ai_bot_enabled
          LlmModel
            .where("enabled_chat_bot = ?", true)
            .pluck(:id)
            .each { |llm_id| rval[llm_id] << { type: :ai_bot } }
        end

        # this is unconditional, so it is clear that we always signal configuration
        AiPersona
          .where("default_llm_id IS NOT NULL")
          .pluck(:default_llm_id, :name, :id)
          .each { |llm_id, name, id| rval[llm_id] << { type: :ai_persona, name: name, id: id } }

        if SiteSetting.ai_helper_enabled
          {
            "#{I18n.t("js.discourse_ai.features.ai_helper.proofread")}" =>
              SiteSetting.ai_helper_proofreader_persona,
            "#{I18n.t("js.discourse_ai.features.ai_helper.title_suggestions")}" =>
              SiteSetting.ai_helper_title_suggestions_persona,
            "#{I18n.t("js.discourse_ai.features.ai_helper.explain")}" =>
              SiteSetting.ai_helper_explain_persona,
            "#{I18n.t("js.discourse_ai.features.ai_helper.illustrate_post")}" =>
              SiteSetting.ai_helper_post_illustrator_persona,
            "#{I18n.t("js.discourse_ai.features.ai_helper.smart_dates")}" =>
              SiteSetting.ai_helper_smart_dates_persona,
            "#{I18n.t("js.discourse_ai.features.ai_helper.translator")}" =>
              SiteSetting.ai_helper_translator_persona,
            "#{I18n.t("js.discourse_ai.features.ai_helper.markdown_tables")}" =>
              SiteSetting.ai_helper_markdown_tables_persona,
            "#{I18n.t("js.discourse_ai.features.ai_helper.custom_prompt")}" =>
              SiteSetting.ai_helper_custom_prompt_persona,
          }.each do |helper_type, persona_id|
            next if persona_id.blank?

            persona = AiPersona.find_by(id: persona_id)
            next if persona.blank? || persona.default_llm_id.blank?

            model_id = persona.default_llm_id || SiteSetting.ai_default_llm_model.to_i
            rval[model_id] << { type: :ai_helper, name: helper_type }
          end
        end

        if SiteSetting.ai_helper_enabled_features.split("|").include?("image_caption")
          image_caption_persona = AiPersona.find_by(id: SiteSetting.ai_helper_image_caption_persona)
          model_id = image_caption_persona.default_llm_id || SiteSetting.ai_default_llm_model.to_i

          rval[model_id] << { type: :ai_helper_image_caption }
        end

        if SiteSetting.ai_summarization_enabled
          summarization_persona = AiPersona.find_by(id: SiteSetting.ai_summarization_persona)
          model_id = summarization_persona.default_llm_id || SiteSetting.ai_default_llm_model.to_i

          rval[model_id] << { type: :ai_summarization }
        end

        if SiteSetting.ai_embeddings_semantic_search_enabled
          search_persona =
            AiPersona.find_by(id: SiteSetting.ai_embeddings_semantic_search_hyde_persona)
          model_id = search_persona.default_llm_id || SiteSetting.ai_default_llm_model.to_i

          rval[model_id] << { type: :ai_embeddings_semantic_search }
        end

        if SiteSetting.ai_spam_detection_enabled && AiModerationSetting.spam.present?
          model_id = AiModerationSetting.spam[:llm_model_id]
          rval[model_id] << { type: :ai_spam }
        end

        if defined?(DiscourseAutomation::Automation)
          DiscourseAutomation::Automation
            .joins(:fields)
            .where(script: %w[llm_report llm_triage])
            .where("discourse_automation_fields.name = ?", "model")
            .pluck(
              "metadata ->> 'value', discourse_automation_automations.name, discourse_automation_automations.id",
            )
            .each do |model_text, name, id|
              next if model_text.blank?
              model_id = model_text.to_i
              rval[model_id] << { type: :automation, name: name, id: id } if model_id.present?
            end
        end

        rval
      end

      def self.valid_value?(val)
        true
      end

      # returns an array of hashes (id: , name:, vision_enabled:)
      def self.values_for_serialization(allowed_seeded_llm_ids: nil)
        builder = DB.build(<<~SQL)
          SELECT id, display_name AS name, vision_enabled
          FROM llm_models
          /*where*/
        SQL

        if allowed_seeded_llm_ids.is_a?(Array) && !allowed_seeded_llm_ids.empty?
          builder.where(
            "id > 0 OR id IN (:allowed_seeded_llm_ids)",
            allowed_seeded_llm_ids: allowed_seeded_llm_ids,
          )
        else
          builder.where("id > 0")
        end

        builder.query_hash.map(&:symbolize_keys)
      end

      def self.values(allowed_seeded_llms: nil)
        values = DB.query_hash(<<~SQL).map(&:symbolize_keys)
          SELECT display_name AS name, id AS value
          FROM llm_models
        SQL

        if allowed_seeded_llms.is_a?(Array)
          values =
            values.filter do |value_h|
              value_h[:value] > 0 || allowed_seeded_llms.include?("#{value_h[:value]}")
            end
        end

        values
      end
    end
  end
end
