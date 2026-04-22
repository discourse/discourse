# frozen_string_literal: true

module Jobs
  class LocalizePosts < ::Jobs::Base
    sidekiq_options retry: false

    REDIS_KEY = "discourse-ai:localize_posts:in_progress"

    def execute(args)
      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.blank? || limit <= 0

      offset = args[:offset].to_i

      return if !DiscourseAi::Translation.backfill_enabled?

      unless DiscourseAi::Translation.credits_available_for_post_localization?
        Rails.logger.info(
          "Translation skipped for posts: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      llm_model = find_llm_model_for_agent(SiteSetting.ai_translation_post_raw_translator_agent)
      return if llm_model.blank?

      locales = DiscourseAi::Translation.locales
      return if locales.blank?

      locale_pairs = locales.map { |l| [l.split("_").first, l] }

      posts =
        DiscourseAi::Translation::PostCandidates
          .get
          .where.not(locale: nil)
          .order(updated_at: :desc)
          .offset(offset)
          .limit(limit)

      return if posts.empty?

      existing =
        PostLocalization.where(post_id: posts.map(&:id)).pluck(:post_id, :locale).group_by(&:first)

      existing_base_locales =
        existing.transform_values { |pairs| pairs.map { |_, loc| loc.split("_").first }.to_set }

      budget = limit
      translated_counts = Hash.new(0)

      posts.each do |post|
        break if budget <= 0
        post_base = post.locale.split("_").first

        locale_pairs.each do |base_locale, target_locale|
          break if budget <= 0
          next if post_base == base_locale
          next if existing_base_locales.dig(post.id)&.include?(base_locale)

          Discourse.redis.expire(REDIS_KEY, 15.minutes.to_i)
          unless DiscourseAi::Translation::PostLocalizer.has_relocalize_quota?(post, target_locale)
            next
          end

          begin
            DiscourseAi::Translation::PostLocalizer.localize(
              post,
              target_locale,
              llm_model: llm_model,
            )
            translated_counts[target_locale] += 1
            budget -= 1
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate post #{post.id} to #{target_locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          end
        end
      end

      translated_counts.each do |target_locale, count|
        DiscourseAi::Translation::VerboseLogger.log("Translated #{count} posts to #{target_locale}")
      end
    ensure
      remaining = Discourse.redis.decr(REDIS_KEY)
      Discourse.redis.del(REDIS_KEY) if remaining <= 0
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
