# frozen_string_literal: true

module Jobs
  class LocalizeSidebarSections < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      return if !DiscourseAi::Translation.enabled?

      unless DiscourseAi::Translation.credits_available_for_sidebar_localization?
        Rails.logger.info(
          "Translation skipped for sidebar sections: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.nil?
      return if limit <= 0

      short_text_llm_model =
        find_llm_model_for_agent(SiteSetting.ai_translation_short_text_translator_agent)
      return if short_text_llm_model.blank?

      sidebar_sections =
        DiscourseAi::Translation::SidebarSectionCandidates
          .get
          .includes(:sidebar_urls)
          .where.not(locale: nil)
          .order(:id)
          .limit(limit)
      return if sidebar_sections.empty?

      changed =
        SidebarSectionLocalization
          .joins(
            "INNER JOIN sidebar_sections ON sidebar_sections.id = sidebar_section_localizations.sidebar_section_id",
          )
          .where(sidebar_section_id: sidebar_sections)
          .where("sidebar_section_localizations.locale = sidebar_sections.locale")
          .delete_all
          .positive?

      changed ||=
        SidebarUrlLocalization
          .joins(
            "INNER JOIN sidebar_urls ON sidebar_urls.id = sidebar_url_localizations.sidebar_url_id",
          )
          .where(sidebar_url_id: sidebar_sections.flat_map(&:sidebar_url_ids))
          .where("sidebar_url_localizations.locale = sidebar_urls.locale")
          .delete_all
          .positive?

      remaining_limit = limit
      locales = SiteSetting.content_localization_supported_locales.split("|")
      sidebar_sections.each do |sidebar_section|
        break if remaining_limit <= 0

        existing_locales =
          SidebarSectionLocalization.where(sidebar_section_id: sidebar_section.id).pluck(:locale)
        missing_locales = locales - existing_locales - [sidebar_section.locale]
        missing_locales.each do |locale|
          break if remaining_limit <= 0
          next if LocaleNormalizer.is_same?(locale, sidebar_section.locale)

          begin
            DiscourseAi::Translation::SidebarSectionLocalizer.localize(
              sidebar_section,
              locale,
              short_text_llm_model:,
            )
            changed = true
          rescue FinalDestination::SSRFDetector::LookupFailedError
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate sidebar section #{sidebar_section.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          ensure
            remaining_limit -= 1
          end
        end
      end

      Site.clear_anon_cache! if changed
    end

    private

    def find_llm_model_for_agent(agent_id)
      return nil if agent_id.blank?

      agent_klass = AiAgent.find_by_id_from_cache(agent_id)
      return nil if agent_klass.blank?

      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(agent_klass)
    end
  end
end
