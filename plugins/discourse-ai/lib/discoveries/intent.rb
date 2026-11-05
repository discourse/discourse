# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    # Asks a decision model whether a search wants an answer or a lookup, and,
    # when it was made from a topic or category, whether it is about that place
    # or the whole site, so the search can open on the tab that suits it.
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
      SCOPE_CHOICES = %w[here site].freeze
      SCOPE_QUESTION = {
        name: "scope",
        type: "choice",
        instructions:
          "The search was made while viewing the forum topic or category in searching_in. " \
            "Choose here when it is about that topic or category, and site when it is about " \
            "the forum in general.",
        choices: SCOPE_CHOICES,
      }.freeze
      # below this the model is no surer than the rules it would replace
      CONFIDENT_PROBABILITY = 0.7
      # The menu waits a second on the verdict before choosing a tab. This applies
      # to each of connecting, sending and reading, not to the call as a whole.
      TIMEOUT_SECONDS = 1

      # What the model chose for a search, each verdict with its probability.
      # Either verdict can be missing when the model refused it.
      Judgement =
        Data.define(:intent, :probability, :scope, :scope_probability) do
          def initialize(intent: nil, probability: nil, scope: nil, scope_probability: nil)
            super
          end

          # a search confidently about the forum in general, not where it was made
          def about_site?
            scope == "site" && scope_probability >= CONFIDENT_PROBABILITY
          end

          def as_json(*)
            to_h.compact
          end
        end

      # Only readers of the combined search are judged, and only when they ask.
      def self.for(user, requested:)
        new(user:) if requested && Discoveries.combined_search_for?(user)
      end

      def self.decision_model
        id = SiteSetting.ai_ask_ai_search_intent_decision_model
        DecisionModel.find_by(id:) if id.present?
      end

      def initialize(user:, decision_model: self.class.decision_model)
        @user = user
        @decision_model = decision_model
      end

      # @param scope [String, nil] the scope key the search was made in
      # @return [Judgement, nil] the intent and, for a topic or category, the scope;
      #   nil when nothing was decided
      def call(query, scope: nil)
        return if @decision_model.nil?

        place = searched_place(scope)
        state = { query: }
        state[:searching_in] = place if place
        questions = [QUESTION]
        questions << SCOPE_QUESTION if place

        client =
          DiscourseAi::Decisions::Client.new(
            @decision_model,
            timeout: TIMEOUT_SECONDS,
            max_attempts: 1,
          )
        result = client.decide(state, questions:, feature_name: FEATURE_NAME, user: @user)

        verdicts = {}
        if (intent = chosen(result[QUESTION[:name]]))
          verdicts.merge!(intent: intent[0], probability: intent[1])
        end
        if place && (scope_choice = chosen(result[SCOPE_QUESTION[:name]]))
          verdicts.merge!(scope: scope_choice[0], scope_probability: scope_choice[1])
        end
        Judgement.new(**verdicts) if verdicts.present?
      rescue DiscourseAi::Decisions::Error => e
        Rails.logger.warn("Discourse AI search intent failed: #{e.class}")
        nil
      end

      private

      # Some models report confidence as certainty across all choices, which is far
      # lower than the chosen one's probability, so the probability is what is kept.
      def chosen(answer)
        return if answer.refusal?

        [answer.choice, answer.probabilities.fetch(answer.choice)]
      end

      # Personal messages are left out: their titles are private to a few people.
      # a category with tags is described by its category
      def searched_place(scope)
        type, id = scope.to_s.split(" ").first.to_s.split(":", 2)
        case type
        when "topic"
          topic = Topic.find_by(id:)
          if topic && !topic.private_message? && @user.guardian.can_see?(topic)
            { type: "topic", title: topic.title }
          end
        when "category"
          category = Category.find_by(id:)
          { type: "category", name: category.name } if category && @user.guardian.can_see?(category)
        end
      end
    end
  end
end
