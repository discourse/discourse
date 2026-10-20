# frozen_string_literal: true

module DiscourseAi
  module AskAi
    # What the search needs from an ask to choose its tab, given the result of
    # `DiscourseAi::AskAi::Ask`.
    class AskSerializer < ApplicationSerializer
      attributes :request_id, :ask_log_id, :intent, :prefers_results, :scope_widened

      def request_id
        object.params.request_id
      end

      def ask_log_id
        object.ask_log.id
      end

      def include_ask_log_id?
        object.ask_log.present?
      end

      def intent
        object.judgement.as_json
      end

      def include_intent?
        object.judgement.present?
      end

      def prefers_results
        true
      end

      def include_prefers_results?
        object.prefers_results.present?
      end

      # the answer was found across the site rather than where the search was made
      def scope_widened
        true
      end

      def include_scope_widened?
        object.params.scope.present? && object.judgement&.about_site?
      end
    end
  end
end
