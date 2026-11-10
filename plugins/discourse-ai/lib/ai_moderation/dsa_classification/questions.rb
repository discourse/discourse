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
        CATEGORY_INSTRUCTIONS = <<~TEXT
          A moderator is acting on this flagged content. Which EU Digital Services Act
          statement of reasons category best describes the grounds for moderation?
          Use the community rules and their explanations to select from the available choices.

          Category specifications from section 16 of
          https://transparency.dsa.ec.europa.eu/page/documentation:
          - Animal welfare
            - Animal harm
            - Unlawful sale of animals
          - Consumer information infringements
            - Hidden advertisement or commercial communication, including by influencers
            - Insufficient information on traders
            - Misleading information about the characteristics of the goods and services
            - Misleading information about the consumer’s rights
            - Non-compliance with pricing regulations
          - Cyber violence
            - Cyber bullying and intimidation
            - Cyber harassment
            - Cyber incitement to hatred or violence
            - Cyber stalking
            - Non-consensual (intimate) material sharing, including (image-based) sexual abuse (excluding content depicting minors)
            - Non-consensual sharing of material containing deepfake or similar technology using a third party's features (excluding content depicting minors)
          - Cyber violence against women
            - Cyber bullying and intimidation against girls
            - Cyber harassment against women
            - Cyber stalking against women
            - Gendered disinformation
            - Illegal incitement to violence and hatred against women
            - Non-consensual (intimate) material sharing against women, including (image-based) sexual abuse against women (excluding content depicting minors)
            - Non-consensual sharing of material containing deepfake or similar technology using a third party's features against women (excluding content depicting minors)
          - Data protection and privacy violations
            - Biometric data breach
            - Data falsification
            - Missing processing ground for data
            - Right to be forgotten
          - Illegal or harmful speech
            - Defamation
            - Discrimination
            - Illegal incitement to violence and hatred based on protected characteristics (hate speech)
          - Intellectual property infringements
            - Copyright infringement
            - Design infringement
            - Geographical indications infringements
            - Patent infringement
            - Trade secret infringement
            - Trademark infringement
          - Negative effects on civic discourse or elections
            - Misinformation, disinformation, foreign information manipulation and interference
            - Violation of EU law relevant to civic discourse or elections
            - Violation of national law relevant to civic discourse or elections
          - Other violation of provider's terms and conditions
            - Adult sexual material
            - Age-specific restrictions
            - Geographical requirements
            - Goods/services not permitted to be offered on the platform
            - Language requirements
            - Nudity
          - Protection of minors
            - Age-specific restrictions concerning minors
            - Child sexual abuse material
            - Child sexual abuse material containing deepfake or similar technology
            - Grooming/sexual enticement of minors
            - Unsafe challenges
          - Risk for public security
            - Illegal organizations
            - Risk for environmental damage
            - Risk for public health
            - Terrorist content
          - Scams and/or fraud
            - Impersonation or account hijacking
            - Inauthentic accounts
            - Inauthentic listings
            - Inauthentic user reviews
            - Phishing
            - Pyramid schemes
          - Self-harm
            - Content promoting eating disorders
            - Self-mutilation
            - Suicide
          - Type of alleged illegal content not specified by the notifier
          - Unsafe, non-compliant or prohibited products
            - Prohibited or restricted products
            - Unsafe or non-compliant products
          - Violence
            - Coordinated harm
            - General calls or incitement to violence and/or hatred
            - Human exploitation
            - Human trafficking
            - Trafficking in women and girls
        TEXT

        def initialize(
          community_rules: DsaStatementOfRecord.community_rules,
          categories: DsaStatementOfRecord::CATEGORIES
        )
          @rule_ids_by_label = community_rules.to_h { |rule| [rule_label(rule), rule_id(rule)] }
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
