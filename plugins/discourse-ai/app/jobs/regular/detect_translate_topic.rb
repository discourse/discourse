# frozen_string_literal: true

module Jobs
  class DetectTranslateTopic < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      return if !DiscourseAi::Translation.enabled? && !source_gist_detection_enabled?
      return if args[:topic_id].blank?

      topic = Topic.find_by(id: args[:topic_id])
      return if topic.blank? || topic.title.blank? || topic.deleted_at.present?

      detected_locale = topic.locale
      enqueue_gist(topic, detected_locale) if detected_locale.present?

      unless DiscourseAi::Translation.credits_available_for_topic_detection?
        Rails.logger.info(
          "Translation skipped for topic: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      force = args[:force] || false
      return if topic.user_id <= 0 && !force && !SiteSetting.ai_translation_include_bot_content

      if force
        # no restrictions
      elsif topic.archetype == Archetype.private_message
        case SiteSetting.ai_translation_personal_messages
        when "all"
          # allow
        when "group"
          return unless TopicAllowedGroup.exists?(topic_id: topic.id)
        else
          return
        end
      else
        return if !DiscourseAi::Translation.category_allowed?(topic.category)
      end

      if detected_locale.blank?
        begin
          detected_locale = DiscourseAi::Translation::TopicLocaleDetector.detect_locale(topic)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # this job is non-critical
          # the backfill job will handle failures
          return
        end

        return if detected_locale.blank?

        enqueue_gist(topic, detected_locale)
      end

      locales = DiscourseAi::Translation.locales
      return if locales.blank?

      existing_base_locales =
        TopicLocalization
          .where(topic_id: topic.id)
          .pluck(:locale)
          .map { |l| l.split("_").first }
          .to_set

      locales.each do |locale|
        next if LocaleNormalizer.is_same?(locale, detected_locale)
        base_locale = locale.split("_").first
        exists = existing_base_locales.include?(base_locale)

        has_quota = DiscourseAi::Translation::TopicLocalizer.has_relocalize_quota?(topic, locale)
        next if !force && exists && !has_quota

        begin
          localization = DiscourseAi::Translation::TopicLocalizer.localize(topic, locale)
          enqueue_gist(topic, locale) if localization
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to translate topic #{topic.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
          )
        end
      end

      MessageBus.publish("/topic/#{topic.id}", reload_topic: true)
    end

    private

    def enqueue_gist(topic, desired_locale)
      return if !SiteSetting.ai_summarization_enabled || !SiteSetting.ai_summary_gists_enabled

      locale =
        DiscourseAi::Summarization
          .gist_locales(topic)
          .find { |candidate| LocaleNormalizer.is_same?(candidate, desired_locale) }
      Jobs.enqueue(:fast_track_topic_gist, topic_id: topic.id, locale:) if locale
    end

    def source_gist_detection_enabled?
      SiteSetting.discourse_ai_enabled && SiteSetting.ai_translation_enabled &&
        DiscourseAi::Translation.has_llm_model? && SiteSetting.ai_summarization_enabled &&
        SiteSetting.ai_summary_gists_enabled
    end
  end
end
