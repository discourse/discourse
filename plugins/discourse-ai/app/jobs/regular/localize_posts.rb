# frozen_string_literal: true

module Jobs
  class LocalizePosts < ::Jobs::Base
    sidekiq_options retry: false

    REDIS_KEY = "discourse-ai:localize_posts:in_progress"

    def execute(args)
      pairs = args[:pairs]
      raise Discourse::InvalidParameters.new(:pairs) if pairs.blank?

      return if !DiscourseAi::Translation.backfill_enabled?

      unless DiscourseAi::Translation.credits_available_for_post_localization?
        Rails.logger.info(
          "Translation skipped for posts: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      llm_model = find_llm_model_for_agent(SiteSetting.ai_translation_post_raw_translator_agent)
      return if llm_model.blank?

      post_ids = pairs.map(&:first).uniq
      posts_by_id = Post.where(id: post_ids).index_by(&:id)

      translated = 0
      pairs.each do |post_id, target_locale|
        post = posts_by_id[post_id]
        next if post.nil?

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
          translated += 1
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to translate post #{post.id} to #{target_locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
          )
        end
      end

      if translated > 0
        DiscourseAi::Translation::VerboseLogger.log(
          "Translated #{translated}/#{pairs.size} post localizations: #{pairs.map { |id, loc| "#{id}:#{loc}" }.join(", ")}",
        )
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
