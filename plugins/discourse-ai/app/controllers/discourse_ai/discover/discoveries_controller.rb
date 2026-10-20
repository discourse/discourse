# frozen_string_literal: true

module DiscourseAi
  module Discover
    class DiscoveriesController < ::ApplicationController
      include AiCreditLimitHandler

      MAX_QUERY_LENGTH = 1000

      requires_plugin PLUGIN_NAME
      requires_login
      before_action :check_permissions!

      def reply
        return legacy_reply if params[:request_id].blank?

        query = normalized_query
        request_id = params[:request_id].to_s
        if !DiscourseAi::Discoveries.valid_request_id?(request_id)
          render_json_error(
            I18n.t("discourse_ai.ai_bot.discoveries.errors.invalid_request_id"),
            status: :bad_request,
          )
          return
        end

        RateLimiter.new(current_user, "ai_discover_#{current_user.id}", 8, 1.minute).performed!

        scope = params[:scope].presence
        if scope && !DiscourseAi::Discoveries.valid_scope?(scope)
          raise Discourse::InvalidParameters.new(:scope)
        end

        trigger = params[:trigger].to_s
        trigger = "" if DiscourseAi::Discoveries::TRIGGERS.exclude?(trigger)
        trigger_reason = params[:trigger_reason].to_s
        if !trigger_reason.match?(DiscourseAi::Discoveries::TRIGGER_REASON_PATTERN)
          trigger_reason = ""
        end

        intent_heuristic = params[:intent_heuristic].to_s
        if DiscourseAi::Discoveries::Intent::CHOICES.exclude?(intent_heuristic)
          intent_heuristic = ""
        end

        judge =
          if params[:classify_intent].to_s == "true" &&
               DiscourseAi::Discoveries.combined_search_for?(current_user)
            DiscourseAi::Discoveries::Intent.new(user: current_user)
          end

        intent = nil
        ask_log =
          DiscourseAi::Discoveries.enqueue_reply(
            user: current_user,
            request_id:,
            query:,
            scope:,
            trigger:,
            trigger_reason:,
            intent_heuristic:,
          ) do |asked_scope|
            # A scoped search is judged before its answer is queued, so the answer
            # can leave a scope the search is not about.
            next asked_scope if !judge || !asked_scope
            intent = judge.call(query, scope: asked_scope)
            DiscourseAi::Discoveries::Intent.about_site?(intent) ? nil : asked_scope
          end

        DiscourseAi::Discoveries.record_recent_ask(user_id: current_user.id, query:)

        # otherwise it is judged after, so it does not hold the answer up
        intent = judge.call(query) if judge && !scope && ask_log
        record_judgement(ask_log, scope:, intent:) if ask_log && (scope || intent)
        scope_widened = true if scope && DiscourseAi::Discoveries::Intent.about_site?(intent)

        prefers_results =
          (
            if DiscourseAi::Discoveries.combined_search_for?(current_user) &&
                 DiscourseAi::Discoveries.prefers_results?(current_user)
              true
            end
          )

        render json: {
                 request_id:,
                 ask_log_id: ask_log&.id,
                 intent:,
                 prefers_results:,
                 scope_widened:,
               }.compact,
               status: :ok
      rescue DiscourseAi::Discoveries::RequestConflict
        render_json_error(
          I18n.t("discourse_ai.ai_bot.discoveries.errors.request_conflict"),
          status: :conflict,
        )
      end

      def record_tabs
        RateLimiter.new(
          current_user,
          "ai_discover_tabs_#{current_user.id}",
          60,
          1.minute,
        ).performed!

        DiscourseAi::Discoveries.record_tabs(
          user: current_user,
          ask_log_id: params.require(:ask_log_id),
          opened: params[:tab_opened].presence,
          opened_reason: params[:tab_opened_reason].to_s,
          switched_to: params[:tab_switched_to].presence,
          switched_after_ms: params[:tab_switched_after_ms],
        )
        head :no_content
      end

      # the Ember app is served for HTML loads before this runs
      def search_page
        head :no_content
      end

      def recent
        render json:
                 success_json.merge(
                   recent_asks: DiscourseAi::Discoveries.recent_asks(user_id: current_user.id),
                 )
      end

      def clear_recent
        DiscourseAi::Discoveries.clear_recent_asks(user_id: current_user.id)
        head :no_content
      end

      def continue_convo
        return legacy_continue_convo if params[:request_id].blank?

        topic_id =
          DiscourseAi::Discoveries::ContinueConversation.new(
            user: current_user,
            discovery_agent: ask_ai_agent,
            follow_up_agent: ask_ai_follow_up_agent,
          ).call(request_id: params[:request_id].to_s, question: params[:question])

        render json: success_json.merge(topic_id:)
      rescue DiscourseAi::Discoveries::ContinueConversation::ResultExpired
        render_json_error(
          I18n.t("discourse_ai.ai_bot.discoveries.errors.result_expired"),
          status: :not_found,
        )
      rescue Discourse::InvalidAccess, Discourse::InvalidParameters
        raise
      rescue StandardError => e
        Rails.logger.error("Discourse AI Discoveries follow-up failed: #{e.class}")
        render_json_error(
          I18n.t("discourse_ai.ai_bot.discoveries.errors.follow_up_failed"),
          status: :unprocessable_entity,
        )
      end

      private

      def legacy_reply
        if ai_discover_agent.default_llm_id.blank? && SiteSetting.ai_default_llm_model.blank?
          render_json_error "Discover agent is missing a default LLM model.", status: 503
          return
        end

        query = normalized_query
        RateLimiter.new(current_user, "ai_discover_#{current_user.id}", 8, 1.minute).performed!
        Jobs.enqueue(:stream_discover_reply, user_id: current_user.id, query:)
        render json: {}, status: :ok
      end

      def legacy_continue_convo
        raise Discourse::InvalidParameters.new("query") if !params[:query]
        raise Discourse::InvalidParameters.new("context") if !params[:context]

        bot_username = User.find_by(id: ai_discover_agent.user_id).username
        RateLimiter.new(
          current_user,
          "ai_discover_#{current_user.id}_continue_convo",
          3,
          1.minute,
        ).performed!

        post =
          PostCreator.create!(
            current_user,
            title:
              I18n.t(
                "discourse_ai.ai_bot.discoveries.continue_conversation.title",
                query: params[:query],
              ),
            raw:
              I18n.t(
                "discourse_ai.ai_bot.discoveries.continue_conversation.raw",
                query: params[:query],
                context: "[quote]\n#{params[:context]}\n[/quote]",
              ),
            archetype: Archetype.private_message,
            target_usernames: bot_username,
            skip_validations: true,
          )

        render json: success_json.merge(topic_id: post.topic_id)
      rescue StandardError => e
        render json: failed_json.merge(errors: [e.message]), status: :unprocessable_entity
      end

      def ai_discover_agent
        @ai_discover_agent ||= AiAgent.find_by_id_from_cache(SiteSetting.ai_discover_agent)
      end

      def ask_ai_agent
        @ask_ai_agent ||= AiAgent.find_by_id_from_cache(SiteSetting.ai_ask_ai_agent)
      end

      def ask_ai_follow_up_agent
        @ask_ai_follow_up_agent ||=
          AiAgent.find_by_id_from_cache(SiteSetting.ai_ask_ai_follow_up_agent)
      end

      def check_permissions!
        if ask_ai_action?
          if !DiscourseAi::Discoveries.enabled_for_user?(current_user)
            raise Discourse::InvalidAccess
          end
          return
        end

        raise Discourse::InvalidAccess if !SiteSetting.ai_discover_enabled
        raise Discourse::InvalidAccess if ai_discover_agent.nil?
        if !current_user.in_any_groups?(ai_discover_agent.allowed_group_ids.to_a)
          raise Discourse::InvalidAccess
        end
        raise Discourse::InvalidAccess if guardian.is_silenced?
      end

      # logged beside the heuristic's guess so the two can be compared
      def record_judgement(ask_log, scope:, intent:)
        ask_log.update!(
          ask_scope: scope.to_s,
          ask_intent_model: intent&.dig(:intent).to_s,
          ask_intent_probability: intent&.dig(:probability) || 0,
          ask_scope_model: intent&.dig(:scope).to_s,
          ask_scope_probability: intent&.dig(:scope_probability) || 0,
        )
      end

      def ask_ai_action?
        %w[search_page recent clear_recent record_tabs].include?(action_name) ||
          params[:request_id].present?
      end

      def normalized_query
        query = params[:query].to_s.strip
        if query.blank? || query.length > MAX_QUERY_LENGTH || query.include?("\0")
          raise Discourse::InvalidParameters.new(
                  I18n.t(
                    "discourse_ai.ai_bot.discoveries.errors.invalid_query",
                    max: MAX_QUERY_LENGTH,
                  ),
                )
        end

        query
      end
    end
  end
end
