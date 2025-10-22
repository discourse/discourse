# frozen_string_literal: true

module Jobs
  class LocalizePosts < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.blank? || limit <= 0

      return if !DiscourseAi::Translation.backfill_enabled?

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

        DiscourseAi::Translation::VerboseLogger.log("Translated #{posts.size} posts to #{locale}")
      end
    end
  end
end
