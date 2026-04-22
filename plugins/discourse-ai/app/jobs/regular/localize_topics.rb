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
        find_llm_model_for_agent(SiteSetting.ai_translation_topic_title_translator_agent)
      post_raw_llm_model =
        find_llm_model_for_agent(SiteSetting.ai_translation_post_raw_translator_agent)
      return if topic_title_llm_model.blank? && post_raw_llm_model.blank?

      locales = DiscourseAi::Translation.locales
      return if locales.blank?

      locale_pairs = locales.map { |l| [l.split("_").first, l] }

      topics =
        DiscourseAi::Translation::TopicCandidates
          .get
          .where.not(locale: nil)
          .order(updated_at: :desc)
          .limit(limit)

      return if topics.empty?

      existing =
        TopicLocalization
          .where(topic_id: topics.map(&:id))
          .pluck(:topic_id, :locale)
          .group_by(&:first)

      existing_base_locales =
        existing.transform_values { |pairs| pairs.map { |_, loc| loc.split("_").first }.to_set }

      budget = limit
      translated_counts = Hash.new(0)

      topics.each do |topic|
        break if budget <= 0
        topic_base = topic.locale.split("_").first

        locale_pairs.each do |base_locale, target_locale|
          break if budget <= 0
          next if topic_base == base_locale
          next if existing_base_locales.dig(topic.id)&.include?(base_locale)

          begin
            DiscourseAi::Translation::TopicLocalizer.localize(
              topic,
              target_locale,
              topic_title_llm_model:,
              post_raw_llm_model:,
            )
            translated_counts[target_locale] += 1
            budget -= 1
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate topic #{topic.id} to #{target_locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          end
        end
      end

      translated_counts.each do |target_locale, count|
        DiscourseAi::Translation::VerboseLogger.log(
          "Translated #{count} topics to #{target_locale}",
        )
      end
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
