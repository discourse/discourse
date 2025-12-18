# frozen_string_literal: true

module Jobs
  class LocalizeTags < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      return if !DiscourseAi::Translation.enabled?

      unless DiscourseAi::Translation.credits_available_for_tag_localization?
        Rails.logger.info(
          "Translation skipped for tags: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.nil?
      return if limit <= 0

      short_text_llm_model =
        find_llm_model_for_persona(SiteSetting.ai_translation_short_text_translator_persona)
      return if short_text_llm_model.blank?

      tags =
        DiscourseAi::Translation::TagCandidates.get.where.not(locale: nil).order(:id).limit(limit)
      return if tags.empty?

      # we remove localizations in locales that match the tag's locale
      TagLocalization
        .joins("INNER JOIN tags ON tags.id = tag_localizations.tag_id")
        .where(tag_id: tags)
        .where("tag_localizations.locale = tags.locale")
        .delete_all

      remaining_limit = limit
      locales = SiteSetting.content_localization_supported_locales.split("|")
      tags.each do |tag|
        break if remaining_limit <= 0

        existing_locales = TagLocalization.where(tag_id: tag.id).pluck(:locale)
        missing_locales = locales - existing_locales - [tag.locale]
        missing_locales.each do |locale|
          break if remaining_limit <= 0
          next if LocaleNormalizer.is_same?(locale, tag.locale)

          begin
            DiscourseAi::Translation::TagLocalizer.localize(tag, locale, short_text_llm_model:)
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate tag #{tag.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          ensure
            remaining_limit -= 1
          end
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
