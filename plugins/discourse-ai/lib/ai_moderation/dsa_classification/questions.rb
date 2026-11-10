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
        CATEGORY_INSTRUCTIONS = <<~TEXT
          A moderator is acting on this flagged content. Which EU Digital Services Act
          statement of reasons category best describes the grounds for moderation?
          Use the community rule and its explanation to identify the grounds. Content
          mentioning a subject is not evidence of a violation in that category.
          Choose the most specific supported category. Do not infer fraud, illegality,
          or protected characteristics from a general community rule violation.

          EU category guidance, summarized from section 16 of
          https://transparency.dsa.ec.europa.eu/page/documentation:
          - Animal welfare: animal harm or unlawful sales.
          - Consumer information infringements: undisclosed ads, trader disclosures,
            misleading product or consumer rights information, pricing compliance.
          - Cyber violence: bullying, harassment, stalking, incitement, nonconsensual
            intimate material or deepfakes concerning adults.
          - Cyber violence against women: gender targeted harassment, stalking,
            disinformation, incitement or nonconsensual intimate material.
          - Data protection and privacy violations: biometric breaches, falsified data,
            missing processing grounds or erasure rights.
          - Illegal or harmful speech: defamation, discrimination or hate speech
            based on protected characteristics.
          - Intellectual property infringements: copyright, design, geographical
            indications, patents, trade secrets or trademarks.
          - Negative effects on civic discourse or elections: misinformation,
            disinformation, interference or relevant election law violations.
          - Type of alleged illegal content not specified by the notifier: an illegal
            content allegation without its type, not a fallback for uncertainty.
          - Other violation of terms and conditions: platform restrictions including
            adult material, age, geography, language or permitted goods and services.
          - Protection of minors: child abuse material, grooming, unsafe challenges
            or age restrictions concerning minors.
          - Risk for public security: illegal organizations, terrorism, environmental
            or public health risks.
          - Scams and fraud: phishing, pyramid schemes, impersonation, hijacked or
            inauthentic accounts, listings or reviews.
          - Self harm: promoting eating disorders, self mutilation or suicide.
          - Unsafe or prohibited products: product safety, compliance or sales restrictions.
          - Violence: coordinated harm, violent incitement, exploitation or trafficking.

          When a community rule violation falls outside the other categories, choose
          Other violation of terms and conditions. For example, unsolicited advertising
          without evidence of fraud should not be classified as Scams and fraud.
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
