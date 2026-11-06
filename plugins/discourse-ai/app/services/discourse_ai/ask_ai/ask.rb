# frozen_string_literal: true

module DiscourseAi
  module AskAi
    # Asks for an AI answer to a search, judging with the decision model which
    # tab the search should open on, and where the answer should look. A search
    # after precise results or private messages can leave the answer for the
    # reader to request, so nothing is generated or sent to a model until then.
    class Ask
      include Service::Base

      params do
        attribute :query, :string
        attribute :request_id, :string
        attribute :scope, :string
        attribute :trigger, :string
        attribute :trigger_reason, :string
        attribute :intent_heuristic, :string
        attribute :classify_intent, :boolean, default: false
        attribute :defer_if_precise, :boolean, default: false
        # Kept as given rather than cast, so a malformed id is refused instead
        # of reading as no id: the controller waives the rate limit for it.
        attribute :deferred_ask_log_id, :string

        # What started a search is only logged, so anything unexpected is
        # dropped rather than refused.

        before_validation do
          self.query = query.to_s.strip
          self.scope = scope.presence
          self.trigger = "" if Discoveries::TRIGGERS.exclude?(trigger)
          self.trigger_reason = trigger_reason.to_s
          self.trigger_reason = "" if !trigger_reason.match?(Discoveries::TRIGGER_REASON_PATTERN)
          self.intent_heuristic = "" if Discoveries::Intent::CHOICES.exclude?(intent_heuristic)
          self.deferred_ask_log_id = deferred_ask_log_id.presence

          # Requesting a held-back answer skips the rate limit, so the request
          # may only claim that answer: never defer again or judge first.
          if deferred_ask_log_id.present?
            self.defer_if_precise = false
            self.classify_intent = false
          end
        end

        validates :query,
                  presence: true,
                  length: {
                    maximum: Discoveries::MAX_QUERY_LENGTH,
                  },
                  format: {
                    without: /\0/,
                  }
        validates :request_id, format: { with: Discoveries::REQUEST_ID_PATTERN }
        validates :scope, format: { with: Discoveries::SCOPE_PATTERN }, allow_nil: true
        validates :deferred_ask_log_id,
                  format: {
                    with: Discoveries::ASK_LOG_ID_PATTERN,
                  },
                  allow_nil: true

        # what the answer job and its log are given
        def answer_attributes
          slice(:request_id, :query, :trigger, :trigger_reason, :intent_heuristic)
        end
      end

      policy :can_ask_ai
      model :request_status, :claim_request
      policy :request_id_matches_query

      only_if(:answer_deferred?) { only_if(:new_request?) { model :ask_log, :log_deferred_ask } }

      only_if(:answer_wanted?) do
        only_if(:new_request?) do
          only_if(:answer_requested_from_search?) { policy :deferred_answer_available }

          # A scoped search is judged before its answer is queued, so the answer
          # can leave a scope the search is not about.
          only_if(:scoped?) do
            model :judgement, :judge_scoped_search, optional: true
            model :ask_log, :queue_scoped_answer
          end

          # Otherwise it is judged once the answer is queued, so it does not hold
          # the answer up.
          only_if(:site_wide?) do
            model :ask_log, :queue_answer
            model :judgement, :judge_search, optional: true
          end

          only_if(:judgement_worth_logging?) { step :log_judgement }
        end

        step :remember_ask
      end

      model :prefers_results, :look_up_reading_preference, optional: true

      private

      def can_ask_ai(guardian:)
        Discoveries.enabled_for_user?(guardian.user)
      end

      def claim_request(params:, guardian:)
        Discoveries.bind_request(
          user_id: guardian.user.id,
          request_id: params.request_id,
          query: params.query,
        )
      end

      def request_id_matches_query(request_status:)
        request_status != :conflict
      end

      def new_request?(request_status:)
        request_status == :created
      end

      def answer_deferred?(params:, guardian:)
        return if !params.defer_if_precise

        Discoveries.precise_search?(params.query) ||
          Discoveries.private_search?(query: params.query, scope: params.scope, guardian:)
      end

      def log_deferred_ask(params:, guardian:)
        Discoveries.log_deferred_ask(
          user: guardian.user,
          scope: params.scope,
          **params.answer_attributes.except(:request_id),
        )
      end

      def answer_wanted?(params:, guardian:)
        !answer_deferred?(params:, guardian:)
      end

      def answer_requested_from_search?(params:)
        params.deferred_ask_log_id.present?
      end

      def deferred_answer_available(params:, guardian:)
        AskAiLog.awaiting_answer(
          id: params.deferred_ask_log_id,
          user: guardian.user,
          query: params.query,
        ).exists?
      end

      def scoped?(params:)
        params.scope.present?
      end

      def judge_scoped_search(params:, guardian:)
        Discoveries::Intent.for(guardian.user, requested: params.classify_intent)&.call(
          params.query,
          scope: params.scope,
        )
      end

      def queue_scoped_answer(params:, guardian:, judgement:)
        Discoveries.enqueue_reply(
          user: guardian.user,
          scope: judgement&.about_site? ? nil : params.scope,
          deferred_log_id: params.deferred_ask_log_id,
          **params.answer_attributes,
        )
      end

      def site_wide?(params:)
        params.scope.blank?
      end

      def queue_answer(params:, guardian:)
        Discoveries.enqueue_reply(
          user: guardian.user,
          deferred_log_id: params.deferred_ask_log_id,
          **params.answer_attributes,
        )
      end

      def judge_search(params:, guardian:)
        Discoveries::Intent.for(guardian.user, requested: params.classify_intent)&.call(
          params.query,
        )
      end

      def judgement_worth_logging?(params:, judgement:)
        params.scope.present? || judgement.present?
      end

      def log_judgement(ask_log:, params:, judgement:)
        ask_log.record_judgement!(scope: params.scope, judgement:)
      end

      def remember_ask(params:, guardian:)
        Discoveries.record_recent_ask(user_id: guardian.user.id, query: params.query)
      end

      def look_up_reading_preference(guardian:)
        Discoveries.combined_search_for?(guardian.user) &&
          Discoveries.prefers_results?(guardian.user)
      end
    end
  end
end
