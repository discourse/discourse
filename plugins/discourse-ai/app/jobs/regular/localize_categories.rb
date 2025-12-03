# frozen_string_literal: true

module Jobs
  class LocalizeCategories < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      return if !DiscourseAi::Translation.enabled?

      unless DiscourseAi::Translation.credits_available_for_category_localization?
        Rails.logger.info(
          "Translation skipped for categories: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.nil?
      return if limit <= 0

      short_text_llm_model =
        find_llm_model_for_persona(SiteSetting.ai_translation_short_text_translator_persona)
      post_raw_llm_model =
        find_llm_model_for_persona(SiteSetting.ai_translation_post_raw_translator_persona)
      return if short_text_llm_model.blank? && post_raw_llm_model.blank?

      categories =
        DiscourseAi::Translation::CategoryCandidates
          .get
          .where.not(locale: nil)
          .order(:id)
          .limit(limit)
      return if categories.empty?

      remaining_limit = limit
      locales = SiteSetting.content_localization_supported_locales.split("|")
      categories.each do |category|
        break if remaining_limit <= 0

        existing_locales = CategoryLocalization.where(category_id: category.id).pluck(:locale)
        missing_locales = locales - existing_locales - [category.locale]
        missing_locales.each do |locale|
          break if remaining_limit <= 0
          next if LocaleNormalizer.is_same?(locale, category.locale)

          begin
            DiscourseAi::Translation::CategoryLocalizer.localize(
              category,
              locale,
              short_text_llm_model:,
              post_raw_llm_model:,
            )
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate category #{category.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          ensure
            remaining_limit -= 1
          end
        end

        if existing_locales.include?(category.locale)
          CategoryLocalization.find_by(category_id: category.id, locale: category.locale).destroy
        end
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
