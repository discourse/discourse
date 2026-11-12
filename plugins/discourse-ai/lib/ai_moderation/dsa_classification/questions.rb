# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    module DsaClassification
      class Questions
        COMMUNITY_RULE = "community_rule"
        CATEGORY = "category"
        COMMUNITY_RULE_INSTRUCTIONS = <<~TEXT.squish
          A moderator is acting on this flagged content. Which of the community's rules does
          the content break? Each choice is a rule followed by its explanation.
        TEXT
        CATEGORY_INSTRUCTIONS = <<~TEXT.squish
          A moderator is acting on this flagged content. Which EU Digital Services Act
          statement of reasons category best describes the grounds for moderation?
          Use the community rules and their explanations to select from the available choices.
        TEXT

        def initialize(
          community_rules: DsaStatementOfRecord.community_rules,
          categories: DsaStatementOfRecord::CATEGORIES
        )
          labels = community_rules.map { |rule| rule_label(rule) }
          if labels.uniq.size != labels.size
            labels = labels.each_with_index.map { |label, index| "#{index + 1}. #{label}" }
          end
          @rule_ids_by_label = labels.zip(community_rules.map { |rule| rule_id(rule) }).to_h
          @category_ids_by_label =
            I18n.with_locale(:en) do
              categories.index_by { |category| I18n.t("dsa_statements.categories.#{category}") }
            end
        end

        def to_a
          [rule_question, category_question].compact
        end

        def suggestion_from(result)
          Suggestion.new(
            community_rule: only_rule_id || chosen(result, COMMUNITY_RULE, @rule_ids_by_label),
            category: chosen(result, CATEGORY, @category_ids_by_label),
          )
        end

        private

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
            instructions:
              "#{CATEGORY_INSTRUCTIONS}\nCommunity rules:\n#{@rule_ids_by_label.keys.join("\n")}",
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
          (explanation.present? ? "#{ground}: #{explanation}" : ground).strip
        end

        def rule_id(rule)
          rule.fetch(DsaStatementOfRecord::COMMUNITY_RULE_ID_KEY)
        end
      end
    end
  end
end
