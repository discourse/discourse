# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    # Asks a decision model whether a search wants an answer or a lookup, so the
    # search menu can open on the tab that suits it.
    class Intent
      FEATURE_NAME = "ai_search_intent"
      CHOICES = %w[answer lookup].freeze
      QUESTION = {
        name: "intent",
        type: "choice",
        instructions:
          "Someone typed this into a community forum's search box. Choose answer when they " \
            "want something explained, solved or summarised, and lookup when they are finding " \
            "a particular topic, page, post, person or term.",
        choices: CHOICES,
      }.freeze
      # the menu waits on this before choosing a tab, so a slow model is skipped
      TIMEOUT_SECONDS = 2

      def self.decision_model
        id = SiteSetting.ai_ask_ai_search_intent_decision_model
        DecisionModel.find_by(id:) if id.present?
      end

      def initialize(user:, decision_model: self.class.decision_model)
        @user = user
        @decision_model = decision_model
      end

      # @return [Hash, nil] the intent and the probability the model gives it, or nil
      #   when no model is set or it could not decide
      def call(query)
        return if @decision_model.nil?

        client =
          DiscourseAi::Decisions::Client.new(
            @decision_model,
            timeout: TIMEOUT_SECONDS,
            max_attempts: 1,
          )
        result =
          client.decide({ query: }, questions: [QUESTION], feature_name: FEATURE_NAME, user: @user)
        answer = result[QUESTION[:name]]
        return if answer.refusal?

        # some models report confidence as certainty across all choices, which is far
        # lower than the chosen one's probability, so the probability is what is kept
        { intent: answer.choice, probability: answer.probabilities.fetch(answer.choice) }
      rescue DiscourseAi::Decisions::Error => e
        Rails.logger.warn("Discourse AI search intent failed: #{e.class}")
        nil
      end
    end
  end
end
