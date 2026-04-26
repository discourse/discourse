# frozen_string_literal: true

module Jobs
  class LocalizeTopics < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      pairs = args[:pairs]
      raise Discourse::InvalidParameters.new(:pairs) if pairs.blank?

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

      topic_ids = pairs.map(&:first).uniq
      topics_by_id = Topic.where(id: topic_ids).index_by(&:id)

      translated = 0
      pairs.each do |topic_id, target_locale|
        topic = topics_by_id[topic_id]
        next if topic.nil?

        begin
          DiscourseAi::Translation::TopicLocalizer.localize(
            topic,
            target_locale,
            topic_title_llm_model:,
            post_raw_llm_model:,
          )
          translated += 1
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to translate topic #{topic.id} to #{target_locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
          )
        end
      end

      if translated > 0
        DiscourseAi::Translation::VerboseLogger.log(
          "Translated #{translated}/#{pairs.size} topic localizations: #{pairs.map { |id, loc| "#{id}:#{loc}" }.join(", ")}",
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
