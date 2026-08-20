# frozen_string_literal: true

module Jobs
  class StreamDiscoverReply < ::Jobs::Base
    sidekiq_options retry: false

    STREAM_INTERVAL = 0.3
    MAX_QUEUE_DELAY = 2.seconds
    REQUEST_DEADLINE = 20.seconds

    def execute(args)
      return if (user = User.find_by(id: args[:user_id])).nil?
      return if (query = args[:query]).blank?
      return if !DiscourseAi::Discoveries.enabled_for_user?(user)
      return if !DiscourseAi::Discoveries.valid_request_id?(args[:request_id])
      return if !active_request?(user, args[:request_id])

      ai_agent = configured_agent(user)
      return if ai_agent.nil?

      llm_model_id = ai_agent.default_llm_id.presence || SiteSetting.ai_default_llm_model
      return if (llm_model = LlmModel.find_by(id: llm_model_id)).nil?

      base = { query:, request_id: args[:request_id] }
      queued_at = Float(args[:queued_at], exception: false)
      if queued_at && Time.now.to_f - queued_at > MAX_QUEUE_DELAY
        publish_unavailable(user, base)
        return
      end

      admitted =
        DiscourseAi::Discoveries.admit_request(user_id: user.id, request_id: args[:request_id])
      if !admitted
        publish_unavailable(user, base)
        return
      end

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + REQUEST_DEADLINE
      cancel_manager = DiscourseAi::Completions::CancelManager.new
      cancel_manager.start_monitor(delay: 0.2) do
        !DiscourseAi::Discoveries.active_request?(user.id, args[:request_id]) ||
          Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      end
      publish_update(user, base.merge(done: false, phase: "searching"))

      retrieval = DiscourseAi::Discoveries::Retrieval.new(user:)
      retrieval_result = retrieval.call(query)
      if cancel_manager.cancelled? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        return
      end
      return if !active_request?(user, args[:request_id])
      if retrieval_result.synthesis_candidates.empty?
        publish_no_answer(user, base)
        return
      end

      preferences = request_preferences(user, args)
      synthesis =
        DiscourseAi::Discoveries::Synthesis.new(user:, ai_agent:, llm_model:, cancel_manager:)
      selected_sources = nil
      selected_refs = nil
      source_selection_invalid = false
      discovery_title = ""
      last_published_answer = ""
      last_streamed_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result =
        synthesis.call(
          query:,
          candidates: retrieval_result.synthesis_candidates,
          show_summary: preferences[:show_summary],
          summary_detail: preferences[:summary_detail],
          related_count: preferences[:related_count],
        ) do |update|
          next if cancel_manager.cancelled? || !active_request?(user, args[:request_id])
          next if !preferences[:show_summary]

          discovery_title = update[:title].to_s.strip if update[:title].present?

          if update[:answerable] == true && update[:source_refs].present? &&
               update[:answer].present?
            streamed_refs = Array(update[:source_refs]).first(preferences[:related_count])
            if selected_refs.present? && selected_refs != streamed_refs
              source_selection_invalid = true
            elsif selected_refs.nil?
              selected_refs = streamed_refs
              selected_sources = retrieval.validated_sources(retrieval_result, selected_refs)
              source_selection_invalid = true if selected_sources.empty?

              if !source_selection_invalid
                publish_update(
                  user,
                  base.merge(
                    done: false,
                    phase: "sources",
                    ai_discover_title: discovery_title,
                    sources: serialize_sources(selected_sources),
                  ),
                )
              end
            end
          end

          next if source_selection_invalid || selected_sources.blank?
          next if update[:answer].blank? || update[:answer] == last_published_answer

          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if last_published_answer.present? && !Rails.env.test? &&
               now - last_streamed_at < STREAM_INTERVAL
            next
          end

          last_published_answer = update[:answer]
          last_streamed_at = now
          publish_update(
            user,
            base.merge(
              done: false,
              phase: "answering",
              ai_discover_title: discovery_title,
              ai_discover_reply: last_published_answer,
            ),
          )
        end

      if cancel_manager.cancelled? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline ||
           !active_request?(user, args[:request_id])
        return
      end

      final_refs = Array(result.source_refs).first(preferences[:related_count])
      final_sources =
        retrieval.validated_sources(retrieval_result, final_refs) if final_refs.present?
      answerable =
        result.answerable && !source_selection_invalid && final_sources.present? &&
          (
            !preferences[:show_summary] ||
              (selected_sources.present? && final_refs == selected_refs && result.answer.present?)
          )

      if answerable
        selected_sources = final_sources
        DiscourseAi::Discoveries.store_result(
          user_id: user.id,
          request_id: args[:request_id],
          query:,
          answer: result.answer,
          sources: selected_sources,
          agent_id: ai_agent.id,
        )
        if !preferences[:show_summary]
          publish_update(
            user,
            base.merge(
              done: false,
              phase: "sources",
              ai_discover_title: "",
              sources: serialize_sources(selected_sources),
            ),
          )
        end
        publish_update(
          user,
          base.merge(
            done: true,
            phase: "complete",
            answerable: true,
            ai_discover_title: result.title,
            ai_discover_reply: result.answer,
            sources: serialize_sources(selected_sources),
          ),
        )
      else
        publish_no_answer(user, base)
      end
    rescue LlmCreditAllocation::CreditLimitExceeded => e
      publish_error_update(user, e, base) if request_still_owned?(user, args[:request_id])
    rescue StandardError => e
      Rails.logger.error("Discourse AI Discoveries request #{args[:request_id]} failed: #{e.class}")
      publish_processing_error(user, base) if request_still_owned?(user, args[:request_id]) && base
    ensure
      cancel_manager&.stop_monitor
      if admitted
        DiscourseAi::Discoveries.release_request(user_id: user.id, request_id: args[:request_id])
      end
    end

    def publish_update(user, payload)
      MessageBus.publish("/discourse-ai/discoveries", payload, user_ids: [user.id])
    end

    def publish_error_update(user, exception, base)
      allocation = exception.allocation

      details = {}
      if allocation
        details[:reset_time_relative] = allocation.relative_reset_time
        details[:reset_time_absolute] = allocation.formatted_reset_time
      end

      payload =
        base.merge(
          error: true,
          error_type: "credit_limit_exceeded",
          message: I18n.t("discourse_ai.ai_bot.discoveries.errors.credits_unavailable"),
          details:,
          ai_discover_reply: "",
          done: true,
          phase: "complete",
        )

      publish_update(user, payload)
    end

    private

    def request_preferences(user, args)
      saved_preferences = DiscourseAi::Discoveries.preferences_for(user)
      show_summary =
        args.key?(:show_summary) ? !!args[:show_summary] : saved_preferences[:show_summary]
      summary_detail = args[:summary_detail].to_s.to_sym
      if !DiscourseAi::Discoveries::SUMMARY_DETAILS.key?(summary_detail)
        summary_detail = saved_preferences[:summary_detail]
      end
      related_count = Integer(args[:related_count], exception: false)
      if !related_count&.between?(
           DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS,
           DiscourseAi::Discoveries::MAX_RELATED_DISCUSSIONS,
         )
        related_count = saved_preferences[:related_count]
      end

      { show_summary:, summary_detail:, related_count: }
    end

    def configured_agent(user)
      agent = AiAgent.find_by_id_from_cache(SiteSetting.ai_discover_agent)
      agent if agent && user.in_any_groups?(agent.allowed_group_ids.to_a)
    end

    def active_request?(user, request_id)
      DiscourseAi::Discoveries.active_request?(user.id, request_id) &&
        DiscourseAi::Discoveries.enabled_for_user?(user)
    end

    def request_still_owned?(user, request_id)
      user && DiscourseAi::Discoveries.active_request?(user.id, request_id)
    end

    def publish_no_answer(user, base)
      publish_update(
        user,
        base.merge(
          done: true,
          phase: "complete",
          answerable: false,
          ai_discover_title: "",
          ai_discover_reply: "",
          sources: [],
        ),
      )
    end

    def publish_processing_error(user, base)
      publish_update(
        user,
        base.merge(
          error: true,
          error_type: "processing_failed",
          message: I18n.t("discourse_ai.ai_bot.discoveries.errors.processing_failed"),
          ai_discover_reply: "",
          done: true,
          phase: "complete",
        ),
      )
    end

    def publish_unavailable(user, base)
      publish_update(
        user,
        base.merge(
          error: true,
          error_type: "temporarily_unavailable",
          message: I18n.t("discourse_ai.ai_bot.discoveries.errors.temporarily_unavailable"),
          ai_discover_reply: "",
          done: true,
          phase: "complete",
        ),
      )
    end

    def serialize_sources(sources)
      sources.map do |source|
        {
          title: source["title"],
          url: source["url"],
          excerpt: source["excerpt"],
          category: source["category"].presence,
          topic_replies: source["topic_replies"].to_i,
          username: source["username"],
          name: source["name"],
          avatar_template: source["avatar_template"],
        }
      end
    end
  end
end
