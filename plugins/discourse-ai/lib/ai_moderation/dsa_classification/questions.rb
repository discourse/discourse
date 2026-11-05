# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    module DsaClassification
      # The classification as decision model questions, and the way back from the labels the
      # model picks to the ids the moderation form submits.
      class Questions
        COMMUNITY_RULE = "community_rule"
        CATEGORY = "category"
        COMMUNITY_RULE_INSTRUCTIONS = <<~TEXT.squish
          A moderator is acting on this flagged content. Which of the community's rules does
          the content break? Each choice is a rule followed by its explanation.
        TEXT
        CATEGORY_INSTRUCTIONS = <<~TEXT.squish
          A moderator is acting on this flagged content. Which EU Digital Services Act
          statement of reasons category best describes why it is being moderated?
        TEXT

        def initialize(
          community_rules: DsaStatementOfRecord.community_rules,
          categories: DsaStatementOfRecord::CATEGORIES
        )
          @rule_ids_by_label = community_rules.to_h { |rule| [rule_label(rule), rule_id(rule)] }
          # Categories are sent in English so every site asks the model the same question.
          @category_ids_by_label =
            I18n.with_locale(:en) do
              categories.index_by { |category| I18n.t("dsa_statements.categories.#{category}") }
            end
        end

        def to_a
          [rule_question, category_question].compact
        end

        # @param result [DiscourseAi::Decisions::Result]
        # @return [Suggestion] a nil field when the model declined to answer it
        def suggestion_from(result)
          Suggestion.new(
            community_rule: only_rule_id || chosen(result, COMMUNITY_RULE, @rule_ids_by_label),
            category: chosen(result, CATEGORY, @category_ids_by_label),
          )
        end

        private

        # A single rule needs no question: it is the only possible answer.
        def rule_question
          return if only_rule_id

          {
            name: COMMUNITY_RULE,
            type: "choice",
            instructions: COMMUNITY_RULE_INSTRUCTIONS,
            choices: @rule_ids_by_label.keys,
          }
        end

        def category_question
          {
            name: CATEGORY,
            type: "choice",
            instructions: CATEGORY_INSTRUCTIONS,
            choices: @category_ids_by_label.keys,
          }
        end

        def only_rule_id
          @rule_ids_by_label.values.first if @rule_ids_by_label.one?
        end

        def chosen(result, question_name, ids_by_label)
          answer = result[question_name]
          ids_by_label[answer.choice] if !answer.refusal?
        end

        def rule_label(rule)
          ground = rule.fetch(DsaStatementOfRecord::COMMUNITY_RULE_GROUND_KEY)
          explanation = rule[DsaStatementOfRecord::COMMUNITY_RULE_EXPLANATION_KEY]
          # Decision questions strip their labels, so ours must match the stripped form.
          (explanation.present? ? "#{ground}: #{explanation}" : ground).strip
        end

        def rule_id(rule)
          rule.fetch(DsaStatementOfRecord::COMMUNITY_RULE_ID_KEY)
        end
      end
    end
  end
end
