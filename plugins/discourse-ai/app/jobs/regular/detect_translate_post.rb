# frozen_string_literal: true

module Jobs
  class DetectTranslatePost < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      return if !DiscourseAi::Translation.enabled?
      return if args[:post_id].blank?

      post = Post.find_by(id: args[:post_id])
      return if post.blank? || post.raw.blank? || post.deleted_at.present? || post.user_id <= 0

      topic = post.topic
      return if topic.blank?

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

      # the user may fill locale in manually
      if (detected_locale = post.locale).blank?
        begin
          detected_locale = DiscourseAi::Translation::PostLocaleDetector.detect_locale(post)
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
        exists = post.localizations.matching_locale(locale).exists?

        if exists && !DiscourseAi::Translation::PostLocalizer.has_relocalize_quota?(post, locale)
          next
        end

        localize(post, locale)
      end

      MessageBus.publish("/topic/#{post.topic_id}", type: :localized, id: post.id)
    end

    private

    def localize(post, locale)
      begin
        DiscourseAi::Translation::PostLocalizer.localize(post, locale)
      rescue FinalDestination::SSRFDetector::LookupFailedError
        # do nothing, there are too many sporadic lookup failures
      rescue => e
        DiscourseAi::Translation::VerboseLogger.log(
          "Failed to translate post #{post.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
        )
      end
    end
  end
end
