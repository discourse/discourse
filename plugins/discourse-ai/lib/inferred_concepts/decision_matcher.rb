# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class DecisionMatcher
      FEATURE_NAME = "inferred_concepts_match"
      MAX_CANDIDATES = 15
      MIN_PROBABILITY = 0.65
      MAX_MATCHES = 5
      MAX_STATE_CHARS = 8_000

      def self.decision_model
        id = SiteSetting.inferred_concepts_match_decision_model
        DecisionModel.find_by(id: id) if id.present?
      end

      def self.available?
        decision_model.present?
      end

      def initialize(decision_model = self.class.decision_model)
        @decision_model = decision_model
      end

      def match(content, candidates:)
        eligible =
          Array(candidates)
            .reject { |concept| concept.respond_to?(:retired?) && concept.retired? }
            .first(MAX_CANDIDATES)
        if content.blank? || eligible.empty? || @decision_model.nil?
          return { matches: [], all_refused: false }
        end

        questions_by_concept =
          eligible.each_with_index.map do |concept, index|
            question = {
              name: "c_#{index}",
              type: "yes_no",
              instructions: build_instructions(concept),
            }
            [question, concept]
          end

        result =
          @decision_model.decide(
            content.to_s.first(MAX_STATE_CHARS),
            questions: questions_by_concept.map(&:first),
            feature_name: FEATURE_NAME,
            user: Discourse.system_user,
          )

        refusals = 0
        matches = []

        questions_by_concept.each do |question, concept|
          answer = result[question[:name]]
          if answer.refusal?
            refusals += 1
            next
          end

          next if answer.probability < MIN_PROBABILITY

          matches << {
            concept_id: concept.id,
            relevance: answer.probability.to_f.clamp(0.0, 1.0),
            primary: false,
          }
        end

        matches = matches.sort_by { |entry| -entry[:relevance] }.first(MAX_MATCHES)
        matches.first[:primary] = true if matches.present?

        { matches: matches, all_refused: refusals == questions_by_concept.size }
      end

      private

      def build_instructions(concept)
        parts = ["Does this forum discussion substantially cover the concept \"#{concept.name}\"?"]
        description = concept.description.to_s.strip.first(300)
        parts << "Definition: #{description}." if description.present?

        aliases = Array(concept.aliases).compact_blank.first(5)
        parts << "Also known as: #{aliases.join(", ")}." if aliases.present?

        parts.join(" ")
      end
    end
  end
end
