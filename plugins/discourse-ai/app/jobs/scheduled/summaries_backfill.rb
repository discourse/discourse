# frozen_string_literal: true

module Jobs
  class SummariesBackfill < ::Jobs::Scheduled
    MAX_CONSECUTIVE_FAILURES = 3

    every 5.minutes
    cluster_concurrency 1

    def execute(_args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_summarization_enabled
      return if SiteSetting.ai_summary_backfill_maximum_topics_per_hour.zero?

      system_user = Discourse.system_user

      backfill_gists(system_user) if SiteSetting.ai_summary_gists_enabled
      backfill_complete_summaries(system_user)
    end

    def try_summarize(strategy, user, topic)
      existing_summary = strategy.existing_summary

      if existing_summary.blank? || existing_summary.outdated
        strategy.summarize(user)
      else
        # Hiding or deleting a post, and creating a small action alters the Topic#highest_post_number.
        # We use this as a quick way to select potential backfill candidates without relying on original_content_sha.
        # At this point, we are confident the summary doesn't need to be regenerated so something other than a regular reply
        # caused the number to change in the topic.
        existing_summary.update!(highest_target_number: topic.highest_post_number)
      end

      true
    rescue => e
      Rails.logger.error("Error summarizing topic #{topic.id}: #{e.class.name} - #{e.message}")
      false
    end

    def backfill_candidates(summary_type, locale:)
      max_age_days = SiteSetting.ai_summary_backfill_topic_max_age_days

      Topic
        .where("topics.word_count >= ?", SiteSetting.ai_summary_backfill_minimum_word_count)
        .joins(<<~SQL)
          LEFT OUTER JOIN ai_summaries ais ON
                          topics.id = ais.target_id AND
                          ais.target_type = 'Topic' AND
                          ais.summary_type = '#{summary_type}'
                          #{locale_join_condition(locale)}
        SQL
        .where("topics.last_posted_at > current_timestamp - INTERVAL '#{max_age_days.to_i} DAY'")
        .where(<<~SQL)
          ais.id IS NULL OR (
            ais.highest_target_number < topics.highest_post_number
            AND ais.updated_at < (current_timestamp - INTERVAL '5 minutes')
          )
        SQL
        .order("ais.updated_at DESC NULLS FIRST, topics.last_posted_at DESC")
    end

    def current_budget(type)
      # Split budget in 12 intervals, but make sure is at least one.
      base_budget = SiteSetting.ai_summary_backfill_maximum_topics_per_hour
      limit_per_job = [base_budget, 12].max / 12

      used_budget =
        AiSummary.system.where("created_at > ?", 1.hour.ago).where(summary_type: type).count

      current_budget = [(base_budget - used_budget), limit_per_job].min
      return 0 if current_budget < 0

      current_budget
    end

    private

    def process_candidates(candidates)
      consecutive_failures = 0

      candidates.each do |candidate|
        if yield(candidate)
          consecutive_failures = 0
        else
          consecutive_failures += 1
          break if consecutive_failures >= MAX_CONSECUTIVE_FAILURES
        end
      end
    end

    def backfill_gists(system_user)
      gist_type = AiSummary.summary_types[:gist]
      budget = current_budget(gist_type)
      return if budget.zero?

      llm_model = find_llm_model(SiteSetting.ai_summary_gists_agent)
      return if !credits_available?(llm_model)

      process_candidates(gist_candidate_pairs(budget)) do |(topic, locale)|
        strategy = DiscourseAi::Summarization.topic_gist(topic, locale:, llm_model:)
        next false if strategy.blank?

        try_summarize(strategy, system_user, topic)
      end
    end

    def backfill_complete_summaries(system_user)
      complete_type = AiSummary.summary_types[:complete]
      budget = current_budget(complete_type)
      return if budget.zero?

      llm_model = find_llm_model(SiteSetting.ai_summarization_agent)
      return if !credits_available?(llm_model)

      process_candidates(
        backfill_candidates(complete_type, locale: :source).limit(budget),
      ) do |topic|
        strategy = DiscourseAi::Summarization.topic_summary(topic, llm_model:)
        next false if strategy.blank?

        try_summarize(strategy, system_user, topic)
      end
    end

    def gist_candidate_pairs(budget)
      selectors = gist_locale_selectors
      rotation = (Time.zone.now.to_i / 5.minutes.to_i) % selectors.length
      candidate_lists =
        selectors
          .rotate(rotation)
          .map do |selector|
            backfill_candidates(AiSummary.summary_types[:gist], locale: selector)
              .limit(budget)
              .filter_map do |topic|
                locale = gist_locale(topic, selector)
                [topic, locale] if locale
              end
          end

      pairs = []
      seen_pairs = Set.new
      while pairs.length < budget && candidate_lists.any?(&:present?)
        candidate_lists.each do |candidates|
          pair = candidates.shift
          next if pair.blank?
          next if !seen_pairs.add?([pair.first.id, pair.second])

          pairs << pair
          break if pairs.length == budget
        end
      end
      pairs
    end

    def gist_locale_selectors
      return [:source] if !SiteSetting.content_localization_enabled

      [*SiteSetting.content_localization_locales, :source]
    end

    def gist_locale(topic, selector)
      locales = DiscourseAi::Summarization.gist_locales(topic)
      desired_locale =
        selector == :source ? DiscourseAi::Summarization.gist_source_locale(topic) : selector

      locales.find { |locale| LocaleNormalizer.is_same?(locale, desired_locale) }
    end

    def locale_join_condition(locale)
      if locale == :source
        default_locale = ActiveRecord::Base.connection.quote(SiteSetting.default_locale)
        return <<~SQL.squish
          AND LOWER(split_part(REPLACE(ais.locale, '-', '_'), '_', 1)) =
              LOWER(split_part(REPLACE(COALESCE(topics.locale, #{default_locale}), '-', '_'), '_', 1))
        SQL
      end

      base_locale =
        LocaleNormalizer.normalize_to_i18n(locale).to_s.tr("-", "_").split("_").first.downcase
      quoted_base_locale = ActiveRecord::Base.connection.quote(base_locale)
      <<~SQL.squish
        AND LOWER(split_part(REPLACE(ais.locale, '-', '_'), '_', 1)) = #{quoted_base_locale}
      SQL
    end

    def credits_available?(llm_model)
      return false if llm_model.blank?
      return true if LlmCreditAllocation.credits_available?(llm_model)

      Rails.logger.info(
        "Summaries backfill skipped: insufficient credits. Will resume when credits reset.",
      )
      false
    end

    def find_llm_model(agent_id)
      agent = AiAgent.find_by_id_from_cache(agent_id)
      return nil if agent.blank?

      agent_class = agent.class_instance
      model_key = agent_class.default_llm_id || SiteSetting.ai_default_llm_model || :last
      @llm_models ||= {}
      @llm_models[model_key] ||= DiscourseAi::Summarization.find_summarization_model(agent_class)
    end
  end
end
