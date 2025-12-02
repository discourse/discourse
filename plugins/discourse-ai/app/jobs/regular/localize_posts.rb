# frozen_string_literal: true

module Jobs
  class LocalizePosts < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.blank? || limit <= 0

      return if !DiscourseAi::Translation.backfill_enabled?

      unless DiscourseAi::Translation.credits_available_for_post_localization?
        Rails.logger.info(
          "Translation skipped for posts: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      llm_model = find_llm_model_for_persona(SiteSetting.ai_translation_post_raw_translator_persona)
      return if llm_model.blank?

      locales = SiteSetting.content_localization_supported_locales.split("|")
      locales.each do |locale|
        base_locale = locale.split("_").first

        posts =
          DiscourseAi::Translation::PostCandidates
            .get
            .joins(
              "LEFT JOIN post_localizations pl ON pl.post_id = posts.id AND pl.locale LIKE '#{base_locale}%'",
            )
            .where.not(locale: nil)
            .where("posts.locale NOT LIKE '#{base_locale}%'")
            .where("pl.id IS NULL")
            .order(updated_at: :desc)
            .limit(limit)

        next if posts.empty?

        posts.each do |post|
          next unless DiscourseAi::Translation::PostLocalizer.has_relocalize_quota?(post, locale)

          begin
            DiscourseAi::Translation::PostLocalizer.localize(post, locale, llm_model: llm_model)
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate post #{post.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          end
        end

        DiscourseAi::Translation::VerboseLogger.log("Translated #{posts.size} posts to #{locale}")
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
