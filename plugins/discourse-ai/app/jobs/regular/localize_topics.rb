# frozen_string_literal: true

module Jobs
  class LocalizeTopics < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.blank? || limit <= 0

      return if !DiscourseAi::Translation.backfill_enabled?

      unless DiscourseAi::Translation.credits_available_for_topic_localization?
        Rails.logger.info(
          "Translation skipped for topics: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      topic_title_llm_model =
        find_llm_model_for_persona(SiteSetting.ai_translation_topic_title_translator_persona)
      post_raw_llm_model =
        find_llm_model_for_persona(SiteSetting.ai_translation_post_raw_translator_persona)
      return if topic_title_llm_model.blank? && post_raw_llm_model.blank?

      locales = SiteSetting.content_localization_supported_locales.split("|")
      locales.each do |locale|
        base_locale = locale.split("_").first
        topics =
          DiscourseAi::Translation::TopicCandidates
            .get
            .joins(
              "LEFT JOIN topic_localizations tl ON tl.topic_id = topics.id AND tl.locale LIKE '#{base_locale}%'",
            )
            .where.not(locale: nil)
            .where("topics.locale NOT LIKE '#{base_locale}%'")
            .where("tl.id IS NULL")
            .order(updated_at: :desc)
            .limit(limit)

        next if topics.empty?

        topics.each do |topic|
          begin
            DiscourseAi::Translation::TopicLocalizer.localize(
              topic,
              locale,
              topic_title_llm_model:,
              post_raw_llm_model:,
            )
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate topic #{topic.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          end
        end

        DiscourseAi::Translation::VerboseLogger.log("Translated #{topics.size} topics to #{locale}")
      end
    end

    private

    def find_llm_model_for_persona(persona_id)
      return nil if persona_id.blank?

      persona_klass = AiPersona.find_by_id_from_cache(persona_id)
      return nil if persona_klass.blank?

      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(persona_klass)
    end
  end
end
