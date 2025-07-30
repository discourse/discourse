# frozen_string_literal: true

module Jobs
  class LocalizeTopics < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.blank? || limit <= 0

      return if !DiscourseAi::Translation.backfill_enabled?

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
            DiscourseAi::Translation::TopicLocalizer.localize(topic, locale)
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
  end
end
