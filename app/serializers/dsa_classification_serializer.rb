# frozen_string_literal: true

class DsaClassificationSerializer < ApplicationSerializer
  attributes :community_rules, :categories

  def community_rules
    DsaStatementOfRecord.community_rules.map do |rule|
      rule.slice(
        DsaStatementOfRecord::COMMUNITY_RULE_ID_KEY,
        DsaStatementOfRecord::COMMUNITY_RULE_GROUND_KEY,
        DsaStatementOfRecord::COMMUNITY_RULE_EXPLANATION_KEY,
      )
    end
  end

  def categories
    DsaStatementOfRecord::CATEGORIES.map do |category|
      { id: category, name: I18n.t("dsa_statements.categories.#{category}") }
    end
  end

  def include_community_rules?
    scope.can_see_review_queue? && DsaStatementOfRecord.classification_enabled?
  end

  alias_method :include_categories?, :include_community_rules?
end
