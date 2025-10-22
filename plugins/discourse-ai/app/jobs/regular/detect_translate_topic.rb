# frozen_string_literal: true

module Jobs
  class DetectTranslateTopic < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      return if !DiscourseAi::Translation.enabled?
      return if args[:topic_id].blank?

      topic = Topic.find_by(id: args[:topic_id])
      if topic.blank? || topic.title.blank? || topic.deleted_at.present? || topic.user_id <= 0
        return
      end

      force = args[:force] || false

      if force
        # no restrictions
      elsif SiteSetting.ai_translation_backfill_limit_to_public_content
        return if topic.category&.read_restricted? || topic.archetype == Archetype.private_message
      else
        if topic.archetype == Archetype.private_message &&
             !TopicAllowedGroup.exists?(topic_id: topic.id)
          return
        end
      end

      if (detected_locale = topic.locale).blank?
        begin
          detected_locale = DiscourseAi::Translation::TopicLocaleDetector.detect_locale(topic)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # this job is non-critical
          # the backfill job will handle failures
          return
        end
      end

      return if detected_locale.blank?
      locales = SiteSetting.content_localization_supported_locales.split("|")
      return if locales.blank?

      locales.each do |locale|
        next if LocaleNormalizer.is_same?(locale, detected_locale)
        next if topic.localizations.matching_locale(locale).exists?

        begin
          DiscourseAi::Translation::TopicLocalizer.localize(topic, locale)
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
  end
end
