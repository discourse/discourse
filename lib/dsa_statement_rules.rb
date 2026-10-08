# frozen_string_literal: true
class DsaStatementRules
  RULES = {
    "personal_attacks" => [
      "Be agreeable, even when you disagree: avoid name calling and personal attacks.",
      "The content directs a personal attack at another participant.",
      "Attacking a participant instead of addressing their ideas violates the rule against personal attacks.",
    ],
    "abusive_content" => [
      "Always be civil: do not post anything offensive or abusive.",
      "The content contains offensive or abusive material.",
      "Offensive or abusive material violates the community requirement to remain civil.",
    ],
    "hate_speech" => [
      "Always be civil: do not post hate speech.",
      "The content contains hate speech.",
      "The content targets people with hate speech, contrary to the community rule prohibiting hate speech.",
    ],
    "harassment" => [
      "Always be civil: do not harass or grief anyone.",
      "The content harasses another person.",
      "Targeting another person with harassment violates the community rule against harassment and griefing.",
    ],
    "obscene_content" => [
      "Always be civil: keep it clean and do not post anything obscene.",
      "The content contains obscene material.",
      "The obscene material violates the community requirement to keep contributions clean.",
    ],
    "sexually_explicit_content" => [
      "Always be civil: do not post anything sexually explicit.",
      "The content contains sexually explicit material.",
      "Sexually explicit material violates the community rule prohibiting such content.",
    ],
    "impersonation" => [
      "Always be civil: do not impersonate people.",
      "The content impersonates another person.",
      "Presenting the content as another person's contribution violates the community rule against impersonation.",
    ],
    "private_information" => [
      "Always be civil: do not expose other people's private information.",
      "The content exposes another person's private information.",
      "Exposing private information about another person violates the community rule protecting privacy.",
    ],
    "spam" => [
      "Always be civil: do not post spam.",
      "The content is spam.",
      "Unwanted spam content violates the community rule against spam.",
    ],
    "vandalism" => [
      "Always be civil: do not vandalize the forum.",
      "The content vandalizes the forum.",
      "The content damages the forum's discussions, contrary to the community rule against vandalism.",
    ],
    "wrong_category" => [
      "Keep it tidy: do not start a topic in the wrong category.",
      "The topic was submitted in the wrong category.",
      "The topic does not belong in the selected category, contrary to the community rule requiring topics to be placed appropriately.",
    ],
    "duplicate_content" => [
      "Keep it tidy: do not cross post the same thing in multiple topics.",
      "The content duplicates a contribution in another topic.",
      "Repeating the same contribution across topics violates the community rule against cross posting.",
    ],
    "empty_reply" => [
      "Keep it tidy: do not post replies with no content.",
      "The reply has no substantive content.",
      "A reply without substantive content violates the community rule requiring meaningful contributions.",
    ],
    "off_topic" => [
      "Keep it tidy: do not divert a topic by changing it midstream.",
      "The content diverts the discussion away from its topic.",
      "Changing the discussion's subject midstream violates the community rule against diverting topics.",
    ],
    "signatures" => [
      "Keep it tidy: do not sign your posts.",
      "The contribution includes a post signature.",
      "Adding a signature to a post violates the community rule against post signatures.",
    ],
    "unauthorized_material" => [
      "Post only your own stuff: do not post digital material belonging to someone else without permission.",
      "The content shares another person's digital material without permission.",
      "Sharing material without the owner's permission violates the community rule requiring permission to post other people's material.",
    ],
    "intellectual_property_theft" => [
      "Post only your own stuff: do not describe methods for stealing intellectual property or post links to such methods.",
      "The content provides methods or links for stealing intellectual property.",
      "Providing methods or links that facilitate intellectual property theft violates the community rule prohibiting those contributions.",
    ],
    "malicious_code" => [
      "Terms of service, Content standards: do not submit malicious computer code, such as computer viruses or spyware.",
      "The content contains malicious computer code.",
      "Submitting malicious code violates the terms prohibiting code that compromises the service or its users.",
    ],
    "unsolicited_advertising" => [
      "Terms of service, Acceptable use: do not send advertisements, chain letters or other solicitations through the forum.",
      "The content is an unsolicited advertisement or solicitation.",
      "Sending unsolicited advertisements or solicitations violates the acceptable use terms.",
    ],
  }.freeze
  private_constant :RULES

  CATEGORIES =
    %w[
      ANIMAL_WELFARE
      CONSUMER_INFORMATION
      CYBER_VIOLENCE
      CYBER_VIOLENCE_AGAINST_WOMEN
      DATA_PROTECTION_AND_PRIVACY_VIOLATIONS
      ILLEGAL_OR_HARMFUL_SPEECH
      INTELLECTUAL_PROPERTY_INFRINGEMENTS
      NEGATIVE_EFFECTS_ON_CIVIC_DISCOURSE_OR_ELECTIONS
      NOT_SPECIFIED_NOTICE
      OTHER_VIOLATION_TC
      PROTECTION_OF_MINORS
      RISK_FOR_PUBLIC_SECURITY
      SCAMS_AND_FRAUD
      SELF_HARM
      UNSAFE_AND_PROHIBITED_PRODUCTS
      VIOLENCE
    ].map { |category| "STATEMENT_CATEGORY_#{category}" }.freeze
  private_constant :CATEGORIES

  def self.rule_names
    RULES.keys
  end

  def self.categories
    CATEGORIES
  end

  def self.fetch(rule)
    mapping = RULES[rule]
    raise Discourse::InvalidParameters.new(:community_rule) unless mapping

    {
      "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
      "incompatible_content_ground" => mapping[0],
      "decision_facts" => mapping[1],
      "incompatible_content_explanation" => mapping[2],
    }
  end
end
