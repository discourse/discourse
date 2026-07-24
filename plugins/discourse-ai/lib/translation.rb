# frozen_string_literal: true

module DiscourseAi
  module Translation
    def self.enabled?
      SiteSetting.discourse_ai_enabled && SiteSetting.ai_translation_enabled && has_llm_model? &&
        SiteSetting.content_localization_supported_locales.present?
    end

    def self.locales
      SiteSetting.content_localization_locales
    end

    def self.supported_locale_bases_cte
      <<~SQL
        supported AS MATERIALIZED (
          SELECT COALESCE(
            array_agg(
              DISTINCT split_part(lower(replace(locale, '-', '_')), '_', 1)
            ) FILTER (WHERE locale IS NOT NULL),
            ARRAY[]::text[]
          ) AS bases
          FROM unnest(ARRAY[:supported_locales]::text[]) configured(locale)
        )
      SQL
    end

    def self.has_llm_model?
      agent_ids = [
        SiteSetting.ai_translation_locale_detector_agent,
        SiteSetting.ai_translation_post_raw_translator_agent,
        SiteSetting.ai_translation_topic_title_translator_agent,
        SiteSetting.ai_translation_short_text_translator_agent,
      ]

      agent_default_llms =
        AiAgent
          .all_agents(enabled_only: false)
          .select { |p| agent_ids.include?(p.id) }
          .map(&:default_llm_id)
      default_llm_model = SiteSetting.ai_default_llm_model

      if agent_default_llms.any?(&:blank?) && default_llm_model.blank?
        false
      else
        true
      end
    end

    def self.backfill_enabled?
      enabled? && SiteSetting.ai_translation_backfill_hourly_rate > 0 &&
        SiteSetting.ai_translation_backfill_max_age_days > 0
    end

    def self.category_ids
      SiteSetting.ai_translation_categories.to_s.split("|").filter_map { |id| id.presence&.to_i }
    end

    def self.category_ids_with_subcategories
      category_ids.flat_map { |category_id| Category.subcategory_ids(category_id) }.uniq
    end

    def self.category_scope_cache_key
      ids =
        case SiteSetting.ai_translation_category_scope
        when "include", "exclude"
          category_ids_with_subcategories
        else
          category_ids
        end

      "#{SiteSetting.ai_translation_category_scope}:#{ids.sort.join("|")}"
    end

    def self.category_scope_condition(category_column:)
      case SiteSetting.ai_translation_category_scope
      when "all"
        ["#{category_column} IS NOT NULL", {}]
      when "include"
        ids = category_ids_with_subcategories
        return "1 = 0", {} if ids.blank?

        ["#{category_column} IN (:category_ids)", { category_ids: ids }]
      when "include_strict"
        ids = category_ids
        return "1 = 0", {} if ids.blank?

        ["#{category_column} IN (:category_ids)", { category_ids: ids }]
      when "exclude"
        ids = category_ids_with_subcategories
        return "#{category_column} IS NOT NULL", {} if ids.blank?

        [
          "#{category_column} IS NOT NULL AND #{category_column} NOT IN (:category_ids)",
          { category_ids: ids },
        ]
      when "exclude_strict"
        ids = category_ids
        return "#{category_column} IS NOT NULL", {} if ids.blank?

        [
          "#{category_column} IS NOT NULL AND #{category_column} NOT IN (:category_ids)",
          { category_ids: ids },
        ]
      else
        [
          "#{category_column} IS NOT NULL AND EXISTS (
            SELECT 1 FROM categories category_scope_categories
            WHERE category_scope_categories.id = #{category_column}
              AND category_scope_categories.read_restricted = false
          )",
          {},
        ]
      end
    end

    def self.category_allowed?(category)
      category_id = category.respond_to?(:id) ? category.id : category
      return false if category_id.blank?

      case SiteSetting.ai_translation_category_scope
      when "all"
        true
      when "include"
        category_ids_with_subcategories.include?(category_id)
      when "include_strict"
        category_ids.include?(category_id)
      when "exclude"
        !category_ids_with_subcategories.include?(category_id)
      when "exclude_strict"
        !category_ids.include?(category_id)
      else
        if category.respond_to?(:read_restricted)
          !category.read_restricted
        else
          Category.where(id: category_id, read_restricted: false).exists?
        end
      end
    end

    def self.llm_model_for_agent(agent_id)
      return nil if agent_id.blank?

      ai_agent = AiAgent.find_by_id_from_cache(agent_id)
      return nil if ai_agent.blank?

      agent_klass = ai_agent.class_instance
      BaseTranslator.preferred_llm_model(agent_klass)
    end

    def self.credits_available_for_agent_ids?(agent_ids)
      return true if agent_ids.blank?

      models = agent_ids.map { |agent_id| llm_model_for_agent(agent_id) }.compact.uniq

      return true if models.empty?

      models.all? { |model| LlmCreditAllocation.credits_available?(model) }
    end

    def self.credits_available_for_post_detection?
      credits_available_for_agent_ids?(
        [
          SiteSetting.ai_translation_locale_detector_agent,
          SiteSetting.ai_translation_post_raw_translator_agent,
        ],
      )
    end

    def self.credits_available_for_topic_detection?
      credits_available_for_agent_ids?(
        [
          SiteSetting.ai_translation_locale_detector_agent,
          SiteSetting.ai_translation_topic_title_translator_agent,
          SiteSetting.ai_translation_post_raw_translator_agent,
        ],
      )
    end

    def self.credits_available_for_post_localization?
      credits_available_for_agent_ids?([SiteSetting.ai_translation_post_raw_translator_agent])
    end

    def self.credits_available_for_topic_localization?
      credits_available_for_agent_ids?(
        [
          SiteSetting.ai_translation_topic_title_translator_agent,
          SiteSetting.ai_translation_post_raw_translator_agent,
        ],
      )
    end

    def self.credits_available_for_category_localization?
      credits_available_for_agent_ids?(
        [
          SiteSetting.ai_translation_short_text_translator_agent,
          SiteSetting.ai_translation_post_raw_translator_agent,
        ],
      )
    end

    def self.credits_available_for_tag_localization?
      credits_available_for_agent_ids?([SiteSetting.ai_translation_short_text_translator_agent])
    end

    def self.credits_available_for_sidebar_localization?
      credits_available_for_agent_ids?([SiteSetting.ai_translation_short_text_translator_agent])
    end
  end
end
